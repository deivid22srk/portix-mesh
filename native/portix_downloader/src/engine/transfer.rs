//! Transferência correta e retomável: stream → `.part` → validar → `rename`.
//!
//! Garantias:
//! - **Escrita atômica**: o destino final só aparece via `rename` após
//!   validação (magic APK, tamanho completo, `fsync`). Crash no meio deixa
//!   apenas um `.part`, nunca um APK corrompido com nome final.
//! - **Retomada real**: `.part.meta` guarda URL, `ETag`/`Last-Modified`,
//!   total e progresso. Retomada usa `Range` + `If-Range`; se o servidor
//!   responder `200` (mudou) ou `416`, recomeça do zero com segurança
//!   (`.ralph/DECISIONS.md` e `resume.rs`).
//! - **Truncamento detectado**: fim de stream antes do `Content-Length`
//!   é erro retentável, nunca sucesso.
//! - **Pré-checagem de espaço**: `statvfs` com margem (restante, na retomada).
//! - **Cancelamento cooperativo** a cada buffer; pausa **mantém** o
//!   `.part`/`.meta` para retomar (descartar de vez é decisão da camada
//!   de serviço). Erros de rede/truncamento também preservam o progresso.

use std::fs::{File, OpenOptions};
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, Instant};

use super::error::DownloadError;
use super::fsutil::{io_error, part_path, remove_if_exists, sanitize_destination, usable_space};
use super::http::{map_ureq_error, validate_url};
use super::progress::{ProgressEvent, ProgressTracker};
use super::resume::ResumeMeta;
use super::retry::{effective_delay, sleep_interruptible, RetryPolicy, RetryRng};
use super::state::{DownloadState, StateTracker};
use super::{parallel, segments};

/// Magic de ZIP/APK (`PK\x03\x04`).
pub const APK_MAGIC: [u8; 4] = [0x50, 0x4B, 0x03, 0x04];
const BUFFER_SIZE: usize = 64 * 1024;
const MAGIC_LEN: usize = 4;
/// Throttle de emissão de progresso (~10/s — a UI não treme).
const PROGRESS_INTERVAL: Duration = Duration::from_millis(100);
/// Margem de segurança sobre o tamanho remoto na checagem de disco.
const DISK_MARGIN_BYTES: i64 = 1024 * 1024;
/// Intervalo de persistência do progresso no `.meta`.
const META_FLUSH_BYTES: i64 = 1024 * 1024;

/// Resultado de uma transferência concluída.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct TransferResult {
    pub bytes: i64,
    pub total: i64,
}

/// Executa o download de `url` para `dest` com retry automático (backoff
/// exponencial + jitter + `Retry-After`), retomando o `.part` entre
/// tentativas quando há validador.
///
/// Callbacks: `on_state` (transições) e `on_progress` (amostras throttled
/// com velocidade/ETA). Em cancelamento/erro retentável o progresso fica
/// no disco para a próxima tentativa; em erro fatal o `.part` é limpo.
pub fn download(
    agent: &ureq::Agent,
    url: &str,
    dest: &Path,
    cancel: &AtomicBool,
    on_state: &mut dyn FnMut(DownloadState),
    on_progress: &mut dyn FnMut(ProgressEvent),
) -> Result<TransferResult, DownloadError> {
    download_with_policy(
        agent,
        url,
        dest,
        cancel,
        &RetryPolicy::default(),
        on_state,
        on_progress,
    )
}

/// Igual a [`download`], com política de retry explícita (usada por testes).
pub fn download_with_policy(
    agent: &ureq::Agent,
    url: &str,
    dest: &Path,
    cancel: &AtomicBool,
    policy: &RetryPolicy,
    on_state: &mut dyn FnMut(DownloadState),
    on_progress: &mut dyn FnMut(ProgressEvent),
) -> Result<TransferResult, DownloadError> {
    if cancel.load(Ordering::SeqCst) {
        return Err(DownloadError::Cancelled);
    }
    sanitize_destination(dest)?;
    validate_url(url)?;

    let mut rng = RetryRng::from_clock();
    let mut attempt_no: u32 = 0;
    loop {
        attempt_no += 1;
        match download_once(agent, url, dest, cancel, on_state, on_progress) {
            Ok(result) => return Ok(result),
            Err(error) => {
                let can_retry = error.is_retryable()
                    && attempt_no < policy.max_attempts
                    && !cancel.load(Ordering::SeqCst);
                if !can_retry {
                    return Err(error);
                }
                let delay = if let DownloadError::Http {
                    retry_after_secs, ..
                } = &error
                {
                    effective_delay(policy, attempt_no, *retry_after_secs, &mut rng)
                } else {
                    effective_delay(policy, attempt_no, None, &mut rng)
                };
                if !sleep_interruptible(delay, cancel) {
                    return Err(DownloadError::Cancelled);
                }
            }
        }
    }
}

/// Uma tentativa de download: retomada v2 (paralela), retomada v1
/// (single-stream) ou sessão nova com probe de capacidade.
fn download_once(
    agent: &ureq::Agent,
    url: &str,
    dest: &Path,
    cancel: &AtomicBool,
    on_state: &mut dyn FnMut(DownloadState),
    on_progress: &mut dyn FnMut(ProgressEvent),
) -> Result<TransferResult, DownloadError> {
    if let Some(meta) = ResumeMeta::load(dest) {
        if meta.can_resume_parallel(url) {
            let validators = (meta.etag.clone(), meta.last_modified.clone());
            let chunks = meta.segments.clone().unwrap_or_default();
            let result = parallel::run_parallel(
                agent,
                url,
                dest,
                cancel,
                meta.total,
                validators,
                chunks,
                &meta,
                on_state,
                on_progress,
            );
            // Validador não bateu: recomeço limpo e seguro (uma vez).
            return match result {
                Err(_e @ (DownloadError::RangeNotSatisfiable | DownloadError::FileChanged)) => {
                    remove_if_exists(&part_path(dest));
                    ResumeMeta::remove(dest);
                    fresh_download(agent, url, dest, cancel, on_state, on_progress)
                }
                other => other,
            };
        }
        if meta.can_resume(url) {
            return match attempt(agent, url, dest, Some(meta), cancel, on_state, on_progress) {
                // Servidor não honrou Range/If-Range: recomeço seguro, uma vez.
                Err(_e @ (DownloadError::RangeNotSatisfiable | DownloadError::FileChanged)) => {
                    remove_if_exists(&part_path(dest));
                    ResumeMeta::remove(dest);
                    attempt(agent, url, dest, None, cancel, on_state, on_progress)
                }
                other => other,
            };
        }
    }
    fresh_download(agent, url, dest, cancel, on_state, on_progress)
}

/// Sessão nova: probe `Range: bytes=0-0` decide entre paralelo e
/// single-stream (fallback automático quando não há suporte a Range).
fn fresh_download(
    agent: &ureq::Agent,
    url: &str,
    dest: &Path,
    cancel: &AtomicBool,
    on_state: &mut dyn FnMut(DownloadState),
    on_progress: &mut dyn FnMut(ProgressEvent),
) -> Result<TransferResult, DownloadError> {
    let capability = parallel::probe(agent, url, cancel)?;
    if let Some(probe) = capability {
        if segments::worker_count(probe.total) > 1 {
            let chunks = segments::plan_chunks(probe.total);
            let meta = ResumeMeta::parallel(
                url,
                probe.total,
                probe.etag.as_deref(),
                probe.last_modified.as_deref(),
                chunks.clone(),
            );
            meta.save(dest);
            return parallel::run_parallel(
                agent,
                url,
                dest,
                cancel,
                probe.total,
                (probe.etag, probe.last_modified),
                chunks,
                &meta,
                on_state,
                on_progress,
            );
        }
    }
    attempt(agent, url, dest, None, cancel, on_state, on_progress)
}

#[allow(clippy::too_many_arguments)]
fn attempt(
    agent: &ureq::Agent,
    url: &str,
    dest: &Path,
    resume: Option<ResumeMeta>,
    cancel: &AtomicBool,
    on_state: &mut dyn FnMut(DownloadState),
    on_progress: &mut dyn FnMut(ProgressEvent),
) -> Result<TransferResult, DownloadError> {
    on_state(DownloadState::Connecting);

    let mut request = agent
        .get(url)
        .set("Accept", "application/vnd.android.package-archive,*/*");
    if let Some(meta) = &resume {
        request = request.set("Range", &format!("bytes={}-{}", meta.done, meta.total - 1));
        if let Some(etag) = &meta.etag {
            request = request.set("If-Range", etag);
        } else if let Some(last_modified) = &meta.last_modified {
            request = request.set("If-Range", last_modified);
        }
    }
    let response = request.call().map_err(map_ureq_error)?;

    let content_type = response
        .header("Content-Type")
        .unwrap_or("")
        .to_ascii_lowercase();
    if content_type.contains("text/html") {
        return Err(DownloadError::NotAnApk("content_type"));
    }

    // Retomada: 200 significa "arquivo mudou ou Range ignorado" → recomeço.
    if let Some(meta) = &resume {
        if response.status() == 200 {
            return Err(DownloadError::FileChanged);
        }
        let content_range = response.header("Content-Range").unwrap_or("");
        let (start, range_total) = parse_content_range(content_range);
        if start != Some(meta.done) || range_total != Some(meta.total) {
            return Err(DownloadError::FileChanged);
        }
    }

    let total: i64 = response
        .header("Content-Length")
        .and_then(|value| value.trim().parse::<i64>().ok())
        .unwrap_or(-1);
    let total = if resume.is_some() {
        // Validado pelo Content-Range acima.
        resume.as_ref().map_or(total, |meta| meta.total)
    } else {
        total
    };

    // Espaço necessário: o que ainda falta baixar + margem.
    let start_done = resume.as_ref().map_or(0, |meta| meta.done);
    if total >= 0 {
        let remaining = total - start_done;
        if let Some(parent) = dest.parent() {
            if let Some(space) = usable_space(parent) {
                if (space as i64) < remaining + DISK_MARGIN_BYTES {
                    return Err(DownloadError::DiskFull);
                }
            }
        }
    }

    let mut states = StateTracker::new();
    states
        .transition(DownloadState::Downloading)
        .map_err(|t| DownloadError::Internal(format!("transição inválida {t:?}")))?;
    on_state(DownloadState::Downloading);

    let part = part_path(dest);
    let mut file = match &resume {
        Some(_) => OpenOptions::new()
            .write(true)
            .open(&part)
            .map_err(io_error)?,
        None => {
            let file = File::create(&part).map_err(io_error)?;
            if total > 0 {
                let _ = file.set_len(total as u64);
            }
            file
        }
    };
    if start_done > 0 {
        file.seek(SeekFrom::Start(start_done as u64))
            .map_err(io_error)?;
    }

    // Meta da sessão: na retomada é a mesma; em sessão nova registra os
    // validadores da resposta e acompanha o progresso para retomada futura.
    let mut live_meta = match &resume {
        Some(meta) => Some(meta.clone()),
        None if total > 0 => {
            let fresh = ResumeMeta::fresh(
                url,
                total,
                response.header("ETag"),
                response.header("Last-Modified"),
            );
            if fresh.etag.is_some() || fresh.last_modified.is_some() {
                fresh.save(dest);
                Some(fresh)
            } else {
                None
            }
        }
        None => None,
    };
    if let Some(meta) = &mut live_meta {
        meta.done = start_done;
    }

    let mut reader = response.into_reader();
    let mut buffer = vec![0u8; BUFFER_SIZE];
    let mut done: i64 = start_done;
    let mut since_meta_flush: i64 = 0;
    let mut tracker = ProgressTracker::new(PROGRESS_INTERVAL);

    let outcome: Result<(), DownloadError> = loop {
        if cancel.load(Ordering::SeqCst) {
            break Err(DownloadError::Cancelled);
        }
        match reader.read(&mut buffer) {
            Ok(0) => break Ok(()),
            Ok(n) => {
                if let Err(e) = file.write_all(&buffer[..n]) {
                    break Err(io_error(e));
                }
                done += n as i64;
                since_meta_flush += n as i64;
                if since_meta_flush >= META_FLUSH_BYTES {
                    since_meta_flush = 0;
                    if let Some(meta) = &mut live_meta {
                        meta.done = done;
                        meta.save(dest);
                    }
                }
                if let Some(event) = tracker.sample(done, total, Instant::now(), false) {
                    on_progress(event);
                }
            }
            Err(e) => break Err(DownloadError::Network(format!("leitura interrompida: {e}"))),
        }
    };

    match outcome {
        Err(error) => {
            drop(file);
            match error {
                // Fatal de conteúdo: retomada não resolve, limpa tudo.
                DownloadError::NotAnApk(_) => {
                    remove_if_exists(&part);
                    ResumeMeta::remove(dest);
                }
                // Cancelamento e falhas de rede/disco preservam o progresso;
                // sem meta (sem validador) não há retomada possível — limpa.
                _ => match &mut live_meta {
                    Some(meta) => {
                        meta.done = done;
                        if meta.done > 0 && meta.done < meta.total {
                            meta.save(dest);
                        } else {
                            remove_if_exists(&part);
                            ResumeMeta::remove(dest);
                        }
                    }
                    None => remove_if_exists(&part),
                },
            }
            let _ = if matches!(error, DownloadError::Cancelled) {
                states.transition(DownloadState::Cancelled)
            } else {
                states.transition(DownloadState::Failed)
            };
            Err(error)
        }
        Ok(()) => {
            states
                .transition(DownloadState::Verifying)
                .map_err(|t| DownloadError::Internal(format!("transição inválida {t:?}")))?;
            on_state(DownloadState::Verifying);

            if let Err(e) = file.sync_all() {
                drop(file);
                remove_if_exists(&part);
                ResumeMeta::remove(dest);
                return Err(io_error(e));
            }
            drop(file);

            // Validação de conteúdo: os 4 primeiros bytes do ARQUIVO precisam
            // ser o magic ZIP — lidos do disco (na retomada a stream da
            // sessão começa no meio do arquivo, então bytes da stream não
            // servem).
            if is_apk_dest(dest) {
                let mut magic = [0u8; MAGIC_LEN];
                let magic_ok = File::open(&part)
                    .and_then(|mut f| f.read_exact(&mut magic))
                    .map(|_| magic == APK_MAGIC)
                    .unwrap_or(false);
                if !magic_ok {
                    remove_if_exists(&part);
                    ResumeMeta::remove(dest);
                    return Err(DownloadError::NotAnApk("magic"));
                }
            }
            // Validação de completude (truncamento não é sucesso).
            if total >= 0 && done != total {
                remove_if_exists(&part);
                ResumeMeta::remove(dest);
                return Err(DownloadError::Truncated { done, total });
            }

            // Concluído: promove o `.part` ao destino final (atômico).
            if let Err(e) = std::fs::rename(&part, dest) {
                remove_if_exists(&part);
                ResumeMeta::remove(dest);
                return Err(io_error(e));
            }
            ResumeMeta::remove(dest);

            let _ = states.transition(DownloadState::Completed);
            on_state(DownloadState::Completed);
            if let Some(event) = tracker.sample(done, total, Instant::now(), true) {
                on_progress(event);
            }
            Ok(TransferResult { bytes: done, total })
        }
    }
}

/// `bytes 100-999/1234` → `(Some(100), Some(1234))`.
fn parse_content_range(value: &str) -> (Option<i64>, Option<i64>) {
    let rest = value
        .trim()
        .strip_prefix("bytes")
        .map(str::trim)
        .unwrap_or("");
    let (range_part, total_part) = rest.split_once('/').unwrap_or(("", ""));
    let start = range_part
        .split('-')
        .next()
        .and_then(|s| s.trim().parse().ok());
    let total = total_part.trim().parse().ok();
    (start, total)
}

fn is_apk_dest(dest: &Path) -> bool {
    dest.extension()
        .and_then(|e| e.to_str())
        .is_some_and(|e| e.eq_ignore_ascii_case("apk"))
}
