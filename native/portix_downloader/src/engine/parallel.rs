//! Download paralelo por chunks com fila de balanceamento.
//!
//! Fluxo:
//! - [`probe`]: `GET Range: bytes=0-0` descobre suporte a Range, total e
//!   validadores (`Accept-Ranges`/`Content-Length`/`ETag`/`Last-Modified`,
//!   como pede a barra de qualidade). 200 = sem Range → single-stream.
//! - [`run_parallel`]: cada worker (≤ [`MAX_CONNECTIONS`]) abre sua conexão
//!   com `Range: pos-end` + `If-Range` (quando há validador), escreve no
//!   `.part` via handle próprio (intervalos disjuntos) e pega o próximo
//!   chunk da fila ao terminar (balanceamento por oversubscription).
//! - A thread principal agrega eventos (mpsc), alimenta progresso/ETA e
//!   persiste a meta v2 (progresso por chunk) a cada ~1 MiB.
//! - Erro em qualquer worker aborta os demais e preserva o progresso no
//!   disco para a retomada; cancelamento idem.

use std::collections::VecDeque;
use std::fs::{File, OpenOptions};
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Instant;

use super::error::DownloadError;
use super::fsutil::{io_error, usable_space};
use super::progress::{ProgressEvent, ProgressTracker};
use super::resume::ResumeMeta;
use super::segments::{worker_count, ChunkState, MAX_CONNECTIONS};
use super::state::DownloadState;
use super::transfer::TransferResult;

const BUFFER_SIZE: usize = 64 * 1024;
/// Mesmo throttle do núcleo single-stream.
const PROGRESS_INTERVAL: std::time::Duration = std::time::Duration::from_millis(100);
const META_FLUSH_BYTES: i64 = 1024 * 1024;
const DISK_MARGIN_BYTES: i64 = 1024 * 1024;

/// Capacidade declarada pelo servidor no probe.
#[derive(Debug, Clone)]
pub struct Probe {
    pub total: i64,
    pub etag: Option<String>,
    pub last_modified: Option<String>,
}

/// `GET Range: bytes=0-0`: `Some(probe)` = servidor suporta Range;
/// `Ok(None)` = não suporta (200) → caller usa single-stream.
pub fn probe(
    agent: &ureq::Agent,
    url: &str,
    cancel: &AtomicBool,
) -> Result<Option<Probe>, DownloadError> {
    if cancel.load(Ordering::SeqCst) {
        return Err(DownloadError::Cancelled);
    }
    let response = agent
        .get(url)
        .set("Range", "bytes=0-0")
        .set("Accept", "application/vnd.android.package-archive,*/*")
        .call()
        .map_err(super::http::map_ureq_error)?;

    if response.status() != 206 {
        // Servidor ignorou o Range (ou respondeu algo inesperado).
        return Ok(None);
    }
    let content_range = response.header("Content-Range").unwrap_or("");
    // "bytes 0-0/262144" ou "bytes 0-0/*"
    let total = content_range
        .rsplit('/')
        .next()
        .and_then(|t| t.trim().parse::<i64>().ok())
        .filter(|t| *t > 0)
        .or_else(|| {
            response
                .header("Content-Length")
                .and_then(|v| v.trim().parse::<i64>().ok())
        });
    let total = match total {
        Some(total) if total > 0 => total,
        _ => return Ok(None),
    };
    Ok(Some(Probe {
        total,
        etag: response
            .header("ETag")
            .filter(|v| !v.is_empty())
            .map(str::to_string),
        last_modified: response
            .header("Last-Modified")
            .filter(|v| !v.is_empty())
            .map(str::to_string),
    }))
}

enum WorkerMsg {
    /// `chunk` avançou para `pos`.
    Position { chunk: usize, pos: u64 },
    /// Worker terminou seu lote com resultado.
    Finished { result: Result<(), DownloadError> },
    /// Validadores observados na primeira resposta (fresh).
    Validators {
        etag: Option<String>,
        last_modified: Option<String>,
    },
}

/// Executa o download em paralelo. `chunks` vem do plano (fresh) ou da meta
/// v2 (retomada); `validators` arma `If-Range` nas retomadas.
#[allow(clippy::too_many_arguments)]
pub fn run_parallel(
    agent: &ureq::Agent,
    url: &str,
    dest: &Path,
    cancel: &AtomicBool,
    total: i64,
    validators: (Option<String>, Option<String>),
    chunks: Vec<ChunkState>,
    meta: &ResumeMeta,
    on_state: &mut dyn FnMut(DownloadState),
    on_progress: &mut dyn FnMut(ProgressEvent),
) -> Result<TransferResult, DownloadError> {
    // Pré-checagem de espaço: o que falta no total (chunks somam o total).
    if let Some(parent) = dest.parent() {
        if let Some(space) = usable_space(parent) {
            let missing: i64 = chunks.iter().map(|c| c.remaining() as i64).sum();
            if (space as i64) < missing + DISK_MARGIN_BYTES {
                return Err(DownloadError::DiskFull);
            }
        }
    }

    let part = super::fsutil::part_path(dest);
    if part.exists() {
        // Garante que o `.part` existe e tem o tamanho total (sparse).
        if let Ok(metadata) = std::fs::metadata(&part) {
            if metadata.len() < total as u64 {
                let extend = OpenOptions::new()
                    .write(true)
                    .open(&part)
                    .map_err(io_error)?;
                let _ = extend.set_len(total as u64);
            }
        }
    } else {
        let file = File::create(&part).map_err(io_error)?;
        let _ = file.set_len(total as u64);
    };

    on_state(DownloadState::Downloading);

    let queue: Arc<Mutex<VecDeque<(usize, ChunkState)>>> = Arc::new(Mutex::new(
        chunks
            .iter()
            .enumerate()
            .filter(|(_, c)| !c.is_done())
            .map(|(i, c)| (i, *c))
            .collect(),
    ));
    // O cancelamento do usuário é observado pelo agregador (abaixo) e
    // propagado aos workers via `abort` — mensagens fluem a cada buffer,
    // então a propagação fica bem abaixo de 200 ms durante a transferência.
    let abort = Arc::new(AtomicBool::new(false));
    let (tx, rx) = std::sync::mpsc::channel::<WorkerMsg>();

    let workers = worker_count(total).clamp(1, MAX_CONNECTIONS);
    let mut handles = Vec::with_capacity(workers);
    for _ in 0..workers {
        let queue = Arc::clone(&queue);
        let abort = Arc::clone(&abort);
        let tx = tx.clone();
        let agent = agent.clone();
        let url = url.to_string();
        let part = part.clone();
        let validators = validators.clone();
        handles.push(std::thread::spawn(move || {
            worker_loop(&agent, &url, &part, &abort, &queue, &validators, &tx)
        }));
    }
    drop(tx);

    // Agregador: espelha posições, emite progresso e persiste a meta.
    let mut mirror: Vec<ChunkState> = chunks.clone();
    let mut tracker = ProgressTracker::new(PROGRESS_INTERVAL);
    let mut etag = validators.0;
    let mut last_modified = validators.1;
    let mut since_flush: i64 = 0;
    let mut result: Result<(), DownloadError> = Ok(());

    for msg in &rx {
        match msg {
            WorkerMsg::Validators {
                etag: e,
                last_modified: l,
            } => {
                etag = e;
                last_modified = l;
            }
            WorkerMsg::Position { chunk, pos } => {
                if let Some(state) = mirror.get_mut(chunk) {
                    let delta = pos.saturating_sub(state.pos);
                    state.pos = pos;
                    since_flush += delta as i64;
                    if since_flush >= META_FLUSH_BYTES {
                        since_flush = 0;
                        meta_flush(dest, meta, &etag, &last_modified, total, &mirror);
                    }
                    let done: i64 = mirror.iter().map(|c| (c.pos - c.start) as i64).sum();
                    if let Some(event) = tracker.sample(done, total, Instant::now(), false) {
                        on_progress(event);
                    }
                }
            }
            WorkerMsg::Finished { result: r } => {
                if let Err(error) = r {
                    if result.is_ok() {
                        result = Err(error);
                        abort.store(true, Ordering::SeqCst);
                    }
                }
            }
        }
        if cancel.load(Ordering::SeqCst) {
            abort.store(true, Ordering::SeqCst);
        }
    }
    for handle in handles {
        let _ = handle.join();
    }
    if cancel.load(Ordering::SeqCst) {
        // Cancelamento do usuário vence qualquer erro de worker.
        meta_flush(dest, meta, &etag, &last_modified, total, &mirror);
        return Err(DownloadError::Cancelled);
    }

    match result {
        Err(error) => {
            // Progresso por chunk já está no disco (flush periódico) —
            // persiste o estado final antes de sair.
            meta_flush(dest, meta, &etag, &last_modified, total, &mirror);
            let _ = mirror;
            let _ = tracker;
            on_state(DownloadState::Failed);
            Err(error)
        }
        Ok(()) => {
            meta_flush(dest, meta, &etag, &last_modified, total, &mirror);
            let all_done = mirror.iter().all(|c| c.is_done());
            if !all_done {
                // Fila drenada com chunks incompletos = impossível sem erro;
                // trata como falha interna (defensivo).
                on_state(DownloadState::Failed);
                return Err(DownloadError::Internal(
                    "chunks incompletos sem erro".into(),
                ));
            }

            on_state(DownloadState::Verifying);
            let handle = File::open(&part).map_err(io_error)?;
            if let Err(e) = handle.sync_all() {
                return Err(io_error(e));
            }
            drop(handle);

            if is_apk_dest(dest) {
                let mut magic = [0u8; 4];
                let magic_ok = File::open(&part)
                    .and_then(|mut f| f.read_exact(&mut magic))
                    .map(|_| magic == super::transfer::APK_MAGIC)
                    .unwrap_or(false);
                if !magic_ok {
                    return Err(DownloadError::NotAnApk("magic"));
                }
            }
            let done: i64 = mirror.iter().map(|c| (c.pos - c.start) as i64).sum();
            if done != total {
                return Err(DownloadError::Truncated { done, total });
            }

            if let Err(e) = std::fs::rename(&part, dest) {
                return Err(io_error(e));
            }
            ResumeMeta::remove(dest);
            on_state(DownloadState::Completed);
            if let Some(event) = tracker.sample(done, total, Instant::now(), true) {
                on_progress(event);
            }
            Ok(TransferResult { bytes: done, total })
        }
    }
}

#[allow(clippy::too_many_arguments)]
fn worker_loop(
    agent: &ureq::Agent,
    url: &str,
    part: &Path,
    abort: &AtomicBool,
    queue: &Mutex<VecDeque<(usize, ChunkState)>>,
    validators: &(Option<String>, Option<String>),
    tx: &std::sync::mpsc::Sender<WorkerMsg>,
) {
    let mut first_response = true;
    loop {
        if abort.load(Ordering::SeqCst) {
            return;
        }
        let Some((index, mut chunk)) = queue.lock().ok().and_then(|mut q| q.pop_front()) else {
            return; // fila vazia: nada mais a fazer
        };
        let outcome = download_chunk(
            agent,
            url,
            part,
            abort,
            &mut chunk,
            validators,
            tx,
            index,
            first_response,
        );
        first_response = false;
        if let Err(error) = outcome {
            let _ = tx.send(WorkerMsg::Finished { result: Err(error) });
            abort.store(true, Ordering::SeqCst);
            return;
        }
        let _ = tx.send(WorkerMsg::Finished { result: Ok(()) });
    }
}

#[allow(clippy::too_many_arguments)]
fn download_chunk(
    agent: &ureq::Agent,
    url: &str,
    part: &Path,
    abort: &AtomicBool,
    chunk: &mut ChunkState,
    validators: &(Option<String>, Option<String>),
    tx: &std::sync::mpsc::Sender<WorkerMsg>,
    index: usize,
    first_response: bool,
) -> Result<(), DownloadError> {
    if chunk.is_done() {
        return Ok(());
    }
    let mut request = agent
        .get(url)
        .set("Range", &format!("bytes={}-{}", chunk.pos, chunk.end - 1))
        .set("Accept", "application/vnd.android.package-archive,*/*");
    if let Some(etag) = &validators.0 {
        request = request.set("If-Range", etag);
    } else if let Some(last_modified) = &validators.1 {
        request = request.set("If-Range", last_modified);
    }
    let response = request.call().map_err(super::http::map_ureq_error)?;

    if first_response {
        let _ = tx.send(WorkerMsg::Validators {
            etag: response
                .header("ETag")
                .filter(|v| !v.is_empty())
                .map(str::to_string),
            last_modified: response
                .header("Last-Modified")
                .filter(|v| !v.is_empty())
                .map(str::to_string),
        });
    }

    if response.status() != 206 {
        // Range ignorado ou arquivo mudou sob If-Range → recomeço seguro.
        return Err(DownloadError::FileChanged);
    }
    let content_range = response.header("Content-Range").unwrap_or("");
    let start = content_range
        .strip_prefix("bytes ")
        .and_then(|rest| rest.split('-').next())
        .and_then(|s| s.trim().parse::<u64>().ok());
    if start != Some(chunk.pos) {
        return Err(DownloadError::FileChanged);
    }

    let mut file = OpenOptions::new()
        .write(true)
        .open(part)
        .map_err(io_error)?;
    file.seek(SeekFrom::Start(chunk.pos)).map_err(io_error)?;

    let mut reader = response.into_reader();
    let mut buffer = vec![0u8; BUFFER_SIZE];
    loop {
        if abort.load(Ordering::SeqCst) {
            return Err(DownloadError::Cancelled);
        }
        match reader.read(&mut buffer) {
            Ok(0) => {
                let _ = tx.send(WorkerMsg::Position {
                    chunk: index,
                    pos: chunk.pos,
                });
                if chunk.pos < chunk.end {
                    return Err(DownloadError::Network(format!(
                        "chunk truncado ({}/{})",
                        chunk.pos - chunk.start,
                        chunk.end - chunk.start
                    )));
                }
                return Ok(());
            }
            Ok(n) => {
                file.write_all(&buffer[..n]).map_err(io_error)?;
                chunk.pos += n as u64;
                let _ = tx.send(WorkerMsg::Position {
                    chunk: index,
                    pos: chunk.pos,
                });
            }
            Err(e) => return Err(DownloadError::Network(format!("leitura interrompida: {e}"))),
        }
    }
}

fn meta_flush(
    dest: &Path,
    meta: &ResumeMeta,
    etag: &Option<String>,
    last_modified: &Option<String>,
    total: i64,
    chunks: &[ChunkState],
) {
    let mut live = meta.clone();
    live.etag = etag.clone().filter(|v| !v.is_empty());
    live.last_modified = last_modified.clone().filter(|v| !v.is_empty());
    live.total = total;
    live.segments = Some(chunks.to_vec());
    let remaining: i64 = chunks.iter().map(|c| c.remaining() as i64).sum();
    if remaining <= 0 {
        // Nada a retomar: não suja o disco com meta vazia.
        return;
    }
    live.save(dest);
}

fn is_apk_dest(dest: &Path) -> bool {
    dest.extension()
        .and_then(|e| e.to_str())
        .is_some_and(|e| e.eq_ignore_ascii_case("apk"))
}
