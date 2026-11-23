//! PORTIX — motor de download de APK.
//!
//! Exposto ao Android via JNI. A classe Kotlin `NativeDownloader` chama
//! `startDownload` (assíncrono, roda numa thread própria) e `cancelDownload`.
//! O progresso é reportado ao `DownloadCallback` (contrato atual preservado:
//! `onProgress(done, total)` e `onComplete(ok, erro)`).
//!
//! Toda a lógica vive em [`engine`], agnóstica de plataforma e testável no
//! host (`cargo test`). Esta ponte apenas adapta: nada de lógica aqui.
//!
//! Contrato de erro em `onComplete(ok = false, erro)`:
//!   `"<code>|<detalhe legível>"` — códigos estáveis em [`engine::error`].
//!   Ex.: `"network|falha de rede: timeout"`, `"not_apk|…"`, `"cancelled|…"`.
//!
//! Assinaturas JNI:
//!   Java_com_deivid22srk_portix_downloader_NativeDownloader_startDownload
//!   Java_com_deivid22srk_portix_downloader_NativeDownloader_cancelDownload

#![allow(non_snake_case)]

/// Núcleo do motor (sem JNI). Público para os testes de integração.
pub mod engine;

use std::collections::HashMap;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};

use jni::objects::{GlobalRef, JClass, JObject, JString, JValue};
use jni::sys::jlong;
use jni::{JNIEnv, JavaVM};

use crate::engine::error::{wire_message, DownloadError};
use crate::engine::progress::ProgressEvent;
use crate::engine::{http, transfer};

/// Intervalo mínimo entre `onProgress` para a notificação/EventChannel
/// (o núcleo amostra a 100 ms; aqui suavizamos o custo de notify).
const NOTIFY_INTERVAL: Duration = Duration::from_millis(300);

static CANCEL_FLAGS: OnceLock<Mutex<HashMap<i64, Arc<AtomicBool>>>> = OnceLock::new();
static NEXT_ID: OnceLock<Mutex<i64>> = OnceLock::new();

fn registry() -> &'static Mutex<HashMap<i64, Arc<AtomicBool>>> {
    CANCEL_FLAGS.get_or_init(|| Mutex::new(HashMap::new()))
}

/// Lock tolerante a poisoning: um pânico em outra thread não derruba novas
/// chamadas JNI (nada de `unwrap` em caminho de produção).
fn lock_registry() -> std::sync::MutexGuard<'static, HashMap<i64, Arc<AtomicBool>>> {
    registry()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

fn next_id() -> i64 {
    let lock = NEXT_ID.get_or_init(|| Mutex::new(0));
    let mut guard = lock.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
    *guard += 1;
    *guard
}

fn jstring_to_string(env: &mut JNIEnv, value: &JString) -> String {
    env.get_string(value)
        .map(|text| text.into())
        .unwrap_or_default()
}

fn emit_progress(env: &mut JNIEnv, callback: &GlobalRef, done: i64, total: i64) {
    let _ = env.call_method(
        callback.as_obj(),
        "onProgress",
        "(JJ)V",
        &[JValue::Long(done), JValue::Long(total)],
    );
}

/// Estatísticas ricas (10/s): bytes, total, velocidade (B/s) e ETA (s;
/// -1 quando desconhecido).
fn emit_stats(
    env: &mut JNIEnv,
    callback: &GlobalRef,
    done: i64,
    total: i64,
    speed_bps: f64,
    eta_secs: i64,
) {
    let _ = env.call_method(
        callback.as_obj(),
        "onStats",
        "(JJDJ)V",
        &[
            JValue::Long(done),
            JValue::Long(total),
            JValue::Double(speed_bps),
            JValue::Long(eta_secs),
        ],
    );
}

/// Transição de estado (códigos estáveis — ver `DownloadCallback` no Kotlin).
fn emit_state(env: &mut JNIEnv, callback: &GlobalRef, state: crate::engine::state::DownloadState) {
    let code = match state {
        crate::engine::state::DownloadState::Connecting => 0,
        crate::engine::state::DownloadState::Downloading => 1,
        crate::engine::state::DownloadState::Verifying => 2,
        crate::engine::state::DownloadState::Completed => 3,
        crate::engine::state::DownloadState::Failed => 4,
        crate::engine::state::DownloadState::Cancelled => 5,
    };
    let _ = env.call_method(callback.as_obj(), "onState", "(I)V", &[JValue::Int(code)]);
}

fn emit_complete(env: &mut JNIEnv, callback: &GlobalRef, ok: bool, error: &str) {
    let value = match env.new_string(error).ok() {
        Some(handle) => JObject::from(handle),
        None => JObject::null(),
    };
    let _ = env.call_method(
        callback.as_obj(),
        "onComplete",
        "(ZLjava/lang/String;)V",
        &[JValue::Bool(ok as u8), JValue::Object(&value)],
    );
}

/// Thread de trabalho: roda o núcleo e traduz o resultado para o callback.
fn run_download(
    jvm: JavaVM,
    callback: GlobalRef,
    id: i64,
    url: String,
    dest: String,
    cancel: Arc<AtomicBool>,
) {
    let outcome = catch_unwind(AssertUnwindSafe(|| {
        let mut env = jvm
            .attach_current_thread()
            .map_err(|error| DownloadError::Internal(error.to_string()))?;

        emit_progress(&mut env, &callback, 0, -1);
        emit_state(
            &mut env,
            &callback,
            crate::engine::state::DownloadState::Connecting,
        );

        // Dois callbacks precisam do `JNIEnv`: `RefCell` divide o acesso na
        // mesma thread (o motor chama um por vez, nunca simultâneo).
        let env_cell = std::cell::RefCell::new(env);
        let agent = http::agent();
        let mut last_notify = Instant::now() - NOTIFY_INTERVAL;
        let mut on_state = |state: crate::engine::state::DownloadState| {
            let mut env = env_cell.borrow_mut();
            emit_state(&mut env, &callback, state);
        };
        let mut on_progress = |event: ProgressEvent| {
            let mut env = env_cell.borrow_mut();
            // Contrato rico a ~10/s para a UI (velocidade/ETA).
            emit_stats(
                &mut env,
                &callback,
                event.done,
                event.total,
                event.speed_bps,
                event.eta_secs.map_or(-1, |s| s as i64),
            );
            // Legado: notificação a ~3/s (economia de bateria).
            let is_final = event.total > 0 && event.done >= event.total;
            if is_final || last_notify.elapsed() >= NOTIFY_INTERVAL {
                last_notify = Instant::now();
                emit_progress(&mut env, &callback, event.done, event.total);
            }
        };

        transfer::download(
            &agent,
            &url,
            Path::new(&dest),
            &cancel,
            &mut on_state,
            &mut on_progress,
        )
    }));

    let error: Option<DownloadError> = match outcome {
        Ok(Ok(_)) => None,
        Ok(Err(error)) => Some(error),
        Err(_) => Some(DownloadError::Internal(
            "pânico capturado na fronteira JNI".into(),
        )),
    };

    // O destino final NUNCA é apagado em erro: o núcleo só toca no `.part`.
    // Um APK bom de um download anterior sobrevive a uma nova tentativa falha.

    if let Ok(mut env) = jvm.attach_current_thread() {
        match &error {
            None => emit_complete(&mut env, &callback, true, ""),
            Some(e) => {
                let message = wire_message(e);
                emit_complete(&mut env, &callback, false, &message);
            }
        }
    }

    lock_registry().remove(&id);
}

#[no_mangle]
pub extern "system" fn Java_com_deivid22srk_portix_downloader_NativeDownloader_startDownload(
    mut env: JNIEnv,
    _class: JClass,
    url: JString,
    dest: JString,
    callback: JObject,
) -> jlong {
    let url = jstring_to_string(&mut env, &url);
    let dest = jstring_to_string(&mut env, &dest);
    if url.is_empty() || dest.is_empty() {
        return 0;
    }

    let jvm = match env.get_java_vm() {
        Ok(vm) => vm,
        Err(_) => return 0,
    };
    let callback = match env.new_global_ref(callback) {
        Ok(reference) => reference,
        Err(_) => return 0,
    };

    let id = next_id();
    let cancel = Arc::new(AtomicBool::new(false));
    lock_registry().insert(id, cancel.clone());

    std::thread::spawn(move || run_download(jvm, callback, id, url, dest, cancel));
    id
}

#[no_mangle]
pub extern "system" fn Java_com_deivid22srk_portix_downloader_NativeDownloader_cancelDownload(
    _env: JNIEnv,
    _class: JClass,
    handle: jlong,
) {
    if let Some(cancel) = lock_registry().get(&handle) {
        cancel.store(true, Ordering::SeqCst);
    }
}
