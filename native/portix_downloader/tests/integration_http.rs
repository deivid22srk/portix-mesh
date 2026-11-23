//! Testes de integração contra um servidor HTTP local de mentira
//! (`std::net`, zero dependências — ver `.ralph/DECISIONS.md` D6).
//!
//! Cenários: 200 completo, truncamento/queda no meio, retomada com 206 +
//! If-Range, ETag mudando (recomeço), 416, sem validador (não retoma),
//! HTML, não-APK, 404, 500, redirect, cancelamento preservando progresso,
//! meta corrompida e preservação do APK anterior. 429 com `Retry-After`
//! entra junto do retry automático (P1).

use std::io::{BufRead, BufReader, Write};
use std::net::{TcpListener, TcpStream};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use portix_downloader::engine::error::DownloadError;
use portix_downloader::engine::progress::ProgressEvent;
use portix_downloader::engine::resume::ResumeMeta;
use portix_downloader::engine::retry;
use portix_downloader::engine::state::DownloadState;
use portix_downloader::engine::{http, transfer};

// ---------------------------------------------------------------------------
// Servidor de mentira
// ---------------------------------------------------------------------------

pub struct MockRequest {
    pub path: String,
    pub headers: Vec<(String, String)>,
}

impl MockRequest {
    pub fn header(&self, name: &str) -> Option<&str> {
        let name = name.to_ascii_lowercase();
        self.headers
            .iter()
            .find(|(k, _)| k.eq_ignore_ascii_case(&name))
            .map(|(_, v)| v.as_str())
    }
}

pub struct MockResponse {
    pub status: u16,
    pub content_type: &'static str,
    pub body: Vec<u8>,
    /// Se definido, responde `Content-Length` maior que o corpo (truncamento).
    pub declared_length: Option<i64>,
    /// Headers extras (ETag, Last-Modified, Content-Range, Location…).
    pub extra: Vec<(String, String)>,
    /// Segundos de espera antes de responder.
    pub delay: Option<Duration>,
    /// Envia `body[..n]`, espera, envia o resto (queda/cancel no meio).
    pub mid_delay: Option<(usize, Duration)>,
}

impl MockResponse {
    fn apk(body: Vec<u8>) -> Self {
        Self {
            status: 200,
            content_type: "application/vnd.android.package-archive",
            body,
            declared_length: None,
            extra: Vec::new(),
            delay: None,
            mid_delay: None,
        }
    }
}

/// Resposta padrão de um probe `Range: bytes=0-0`: 206 com 1 byte,
/// `Content-Range` completo e o ETag do arquivo.
pub fn probe_response(body: &[u8], etag: &str) -> MockResponse {
    MockResponse {
        status: 206,
        content_type: "application/vnd.android.package-archive",
        body: body[..1].to_vec(),
        declared_length: Some(1),
        extra: vec![
            ("Content-Range".into(), format!("bytes 0-0/{}", body.len())),
            ("ETag".into(), format!("\"{etag}\"")),
        ],
        delay: None,
        mid_delay: None,
    }
}

/// O request é um probe de capacidade?
pub fn is_probe(req: &MockRequest) -> bool {
    req.header("Range") == Some("bytes=0-0")
}

pub struct MockServer {
    pub url: String,
    requests: Arc<AtomicUsize>,
    #[allow(dead_code)]
    listener: std::net::SocketAddr,
}

impl MockServer {
    /// Sobe o servidor numa porta efêmera com o handler fixo.
    pub fn start(handler: impl Fn(&MockRequest) -> MockResponse + Send + Sync + 'static) -> Self {
        let listener = TcpListener::bind("127.0.0.1:0").expect("bind");
        let addr = listener.local_addr().expect("addr");
        let requests = Arc::new(AtomicUsize::new(0));
        let counter = Arc::clone(&requests);
        std::thread::spawn(move || {
            for stream in listener.incoming() {
                let Ok(stream) = stream else { continue };
                counter.fetch_add(1, Ordering::SeqCst);
                handle_connection(stream, &handler);
            }
        });
        MockServer {
            url: format!("http://{addr}/app.apk"),
            requests,
            listener: addr,
        }
    }

    pub fn request_count(&self) -> usize {
        self.requests.load(Ordering::SeqCst)
    }
}

fn handle_connection(mut stream: TcpStream, handler: &dyn Fn(&MockRequest) -> MockResponse) {
    let _ = stream.set_read_timeout(Some(Duration::from_secs(10)));
    let Ok(peer) = stream.try_clone() else { return };
    let mut reader = BufReader::new(peer);

    let mut request_line = String::new();
    if reader.read_line(&mut request_line).is_err() {
        return;
    }
    let mut parts = request_line.split_whitespace();
    let _method = parts.next().unwrap_or_default();
    let path = parts.next().unwrap_or("/").to_string();

    let mut headers = Vec::new();
    loop {
        let mut line = String::new();
        match reader.read_line(&mut line) {
            Ok(0) => break,
            Ok(_) if line.trim_end().is_empty() => break,
            Ok(_) => {
                if let Some((k, v)) = line.trim_end().split_once(':') {
                    headers.push((k.trim().to_string(), v.trim().to_string()));
                }
            }
            Err(_) => break,
        }
    }

    let request = MockRequest { path, headers };
    let response = handler(&request);

    if let Some(delay) = response.delay {
        std::thread::sleep(delay);
    }

    let status_text = match response.status {
        200 => "OK",
        206 => "Partial Content",
        302 => "Found",
        404 => "Not Found",
        416 => "Range Not Satisfiable",
        429 => "Too Many Requests",
        500 => "Internal Server Error",
        _ => "Status",
    };
    let length = response
        .declared_length
        .unwrap_or(response.body.len() as i64);
    let mut head = format!(
        "HTTP/1.1 {} {status_text}\r\nContent-Type: {}\r\nContent-Length: {length}\r\nConnection: close\r\n",
        response.status, response.content_type
    );
    for (key, value) in &response.extra {
        head.push_str(&format!("{key}: {value}\r\n"));
    }
    head.push_str("\r\n");
    let _ = stream.write_all(head.as_bytes());

    match response.mid_delay {
        Some((split, pause)) => {
            let _ = stream.write_all(&response.body[..split]);
            let _ = stream.flush();
            std::thread::sleep(pause);
            let _ = stream.write_all(&response.body[split..]);
        }
        None => {
            let _ = stream.write_all(&response.body);
        }
    }
    let _ = stream.flush();
}

// ---------------------------------------------------------------------------
// Helpers de teste
// ---------------------------------------------------------------------------

fn fake_apk(size: usize) -> Vec<u8> {
    let mut body = vec![0u8; size];
    body[0] = b'P';
    body[1] = b'K';
    body[2] = 0x03;
    body[3] = 0x04;
    for (i, byte) in body.iter_mut().enumerate().skip(4) {
        *byte = (i % 251) as u8;
    }
    body
}

struct ScratchDir(PathBuf);

impl ScratchDir {
    fn new(tag: &str) -> Self {
        let dir = std::env::temp_dir().join(format!("portix-test-{tag}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).expect("mkdir");
        ScratchDir(dir)
    }

    fn apk(&self) -> PathBuf {
        self.0.join("portix-1.apk")
    }

    fn part(&self) -> PathBuf {
        self.0.join("portix-1.apk.part")
    }
}

impl Drop for ScratchDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

fn run(
    url: &str,
    dest: &Path,
    cancel: &AtomicBool,
    states: &mut Vec<DownloadState>,
    progress: &mut Vec<ProgressEvent>,
) -> Result<transfer::TransferResult, DownloadError> {
    // Política sem retry: os cenários abaixo controlam as tentativas à mão.
    let no_retry = retry::RetryPolicy {
        max_attempts: 1,
        ..retry::RetryPolicy::default()
    };
    run_with(url, dest, cancel, &no_retry, states, progress)
}

fn run_with(
    url: &str,
    dest: &Path,
    cancel: &AtomicBool,
    policy: &retry::RetryPolicy,
    states: &mut Vec<DownloadState>,
    progress: &mut Vec<ProgressEvent>,
) -> Result<transfer::TransferResult, DownloadError> {
    let agent = http::agent();
    transfer::download_with_policy(
        &agent,
        url,
        dest,
        cancel,
        policy,
        &mut |state| states.push(state),
        &mut |event| progress.push(event),
    )
}

static NO_CANCEL: AtomicBool = AtomicBool::new(false);

const HALF: i64 = 128 * 1024;
const FULL: i64 = 256 * 1024;

// ---------------------------------------------------------------------------
// Cenários básicos
// ---------------------------------------------------------------------------

#[test]
fn download_200_completo_promove_rename() {
    let body = fake_apk(FULL as usize);
    let expected = body.clone();
    let server = MockServer::start(move |_| MockResponse::apk(expected.clone()));
    let scratch = ScratchDir::new("ok");
    let dest = scratch.apk();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let result = run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).expect("ok");

    assert_eq!(result.bytes, FULL);
    assert_eq!(result.total, FULL);
    assert_eq!(std::fs::read(&dest).expect("arquivo final"), body);
    assert!(
        !scratch.part().exists(),
        ".part deve ser renomeado, não deixado"
    );
    assert!(states.contains(&DownloadState::Downloading));
    assert!(states.contains(&DownloadState::Verifying));
    assert!(states.contains(&DownloadState::Completed));
    assert!(progress.iter().any(|p| p.speed_bps > 0.0));
}

#[test]
fn stream_truncada_e_erro_e_nao_promove() {
    let body = fake_apk(HALF as usize);
    let server = MockServer::start(move |_| MockResponse {
        // Declara o total mas manda metade — a conexão caiu "de graça".
        declared_length: Some(FULL),
        ..MockResponse::apk(body.clone())
    });
    let scratch = ScratchDir::new("trunc");
    let dest = scratch.apk();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let err = run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).unwrap_err();

    // O ureq detecta corpo fechado antes do total (Network); a checagem
    // própria de `done != Content-Length` (Truncated) é a segunda linha de
    // defesa. Ambos são retentáveis e nunca promovem o arquivo.
    assert!(
        matches!(
            err,
            DownloadError::Truncated { .. } | DownloadError::Network(_)
        ),
        "esperado Truncated/Network, veio {err:?}"
    );
    if let DownloadError::Truncated { done, total } = err {
        assert_eq!(done, HALF);
        assert_eq!(total, FULL);
    }
    assert!(err.is_retryable());
    assert!(
        !dest.exists(),
        "destino final não pode aparecer com arquivo truncado"
    );
    assert!(
        !scratch.part().exists(),
        ".part limpo após erro (sem validador não há retomada)"
    );
}

#[test]
fn html_e_rejeitado_por_content_type() {
    let server = MockServer::start(|_| MockResponse {
        status: 200,
        content_type: "text/html; charset=utf-8",
        body: b"<html><body>pagina do telegram</body></html>".to_vec(),
        declared_length: None,
        extra: Vec::new(),
        delay: None,
        mid_delay: None,
    });
    let scratch = ScratchDir::new("html");
    let dest = scratch.apk();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let err = run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).unwrap_err();
    assert!(
        matches!(err, DownloadError::NotAnApk("content_type")),
        "{err:?}"
    );
    assert!(!dest.exists());
}

#[test]
fn corpo_sem_magic_e_rejeitado() {
    let server = MockServer::start(|_| {
        MockResponse::apk(b"este nao e um zip valido de forma alguma".to_vec())
    });
    let scratch = ScratchDir::new("magic");
    let dest = scratch.apk();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let err = run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).unwrap_err();
    assert!(matches!(err, DownloadError::NotAnApk("magic")), "{err:?}");
    assert!(!dest.exists());
}

#[test]
fn http_404_e_fatal_com_codigo_estavel() {
    let server = MockServer::start(|_| MockResponse {
        status: 404,
        content_type: "text/plain",
        body: b"nope".to_vec(),
        declared_length: None,
        extra: Vec::new(),
        delay: None,
        mid_delay: None,
    });
    let scratch = ScratchDir::new("404");
    let dest = scratch.apk();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let err = run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).unwrap_err();
    assert!(
        matches!(err, DownloadError::Http { status: 404, .. }),
        "{err:?}"
    );
    assert!(!err.is_retryable());
    assert_eq!(err.code(), "http_status");
}

#[test]
fn http_500_e_retentavel() {
    let server = MockServer::start(|_| MockResponse {
        status: 500,
        content_type: "text/plain",
        body: b"boom".to_vec(),
        declared_length: None,
        extra: Vec::new(),
        delay: None,
        mid_delay: None,
    });
    let scratch = ScratchDir::new("500");
    let dest = scratch.apk();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let err = run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).unwrap_err();
    assert!(
        matches!(err, DownloadError::Http { status: 500, .. }),
        "{err:?}"
    );
    assert!(err.is_retryable());
}

#[test]
fn url_invalida_falha_rapido() {
    let scratch = ScratchDir::new("badurl");
    let dest = scratch.apk();
    let mut states = Vec::new();
    let mut progress = Vec::new();
    for bad in [
        "",
        "   ",
        "ftp://x/y.apk",
        "file:///etc/passwd",
        "javascript:alert(1)",
    ] {
        let err = run(bad, &dest, &NO_CANCEL, &mut states, &mut progress).unwrap_err();
        assert_eq!(err.code(), "invalid_url", "{bad}");
    }
}

#[test]
fn cancelamento_antes_de_conectar_nao_abre_conexao() {
    let body = fake_apk(FULL as usize);
    let server = MockServer::start(move |_| MockResponse::apk(body.clone()));
    let scratch = ScratchDir::new("cancel0");
    let dest = scratch.apk();

    let cancel = AtomicBool::new(true); // já chega cancelado
    let mut states = Vec::new();
    let mut progress = Vec::new();
    let err = run(&server.url, &dest, &cancel, &mut states, &mut progress).unwrap_err();
    assert_eq!(err.code(), "cancelled");
    assert!(!dest.exists());
    assert!(!scratch.part().exists());
    assert_eq!(server.request_count(), 0, "não deve nem abrir conexão");
}

#[test]
fn apk_anterior_sobrevive_a_nova_tentativa_falha() {
    let body = fake_apk(64 * 1024);
    let server_ok = MockServer::start(move |_| MockResponse::apk(body.clone()));
    let scratch = ScratchDir::new("survive");
    let dest = scratch.apk();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    run(
        &server_ok.url,
        &dest,
        &NO_CANCEL,
        &mut states,
        &mut progress,
    )
    .expect("primeiro ok");
    let original = std::fs::read(&dest).expect("apk bom");

    let server_bad = MockServer::start(|_| MockResponse {
        status: 404,
        content_type: "text/plain",
        body: b"nope".to_vec(),
        declared_length: None,
        extra: Vec::new(),
        delay: None,
        mid_delay: None,
    });
    let err = run(
        &server_bad.url,
        &dest,
        &NO_CANCEL,
        &mut states,
        &mut progress,
    )
    .unwrap_err();
    assert!(matches!(err, DownloadError::Http { status: 404, .. }));
    assert_eq!(std::fs::read(&dest).expect("apk intacto"), original);
}

#[test]
fn progresso_respeita_total_da_resposta() {
    let body = fake_apk(512 * 1024);
    let server = MockServer::start(move |_| MockResponse::apk(body.clone()));
    let scratch = ScratchDir::new("progress");
    let dest = scratch.apk();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let result = run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).expect("ok");
    assert_eq!(result.total, 512 * 1024);
    let last = progress.last().expect("houve progresso");
    assert_eq!(last.done, result.bytes);
    assert_eq!(last.total, result.total);
}

// ---------------------------------------------------------------------------
// Retomada (Range + If-Range)
// ---------------------------------------------------------------------------

/// Handler com estado: 1ª request manda metade e fecha; as seguintes servem
/// 206 com o resto quando o `If-Range` bate, ou 200 completo quando mudou.
fn resume_handler(
    body: Vec<u8>,
    etag: &'static str,
    behavior_second: SecondBehavior,
    seen: Arc<Mutex<Vec<String>>>,
) -> impl Fn(&MockRequest) -> MockResponse {
    let counter = Arc::new(AtomicUsize::new(0));
    move |req: &MockRequest| {
        if is_probe(req) {
            return probe_response(&body, etag);
        }
        seen.lock().unwrap().push(format!(
            "path={} range={:?} if_range={:?}",
            req.path,
            req.header("Range"),
            req.header("If-Range")
        ));
        let n = counter.fetch_add(1, Ordering::SeqCst);
        if n <= 1 {
            // Duas quedas: a sessão inicial E o rescue automático falham,
            // para exercitar a retomada explícita da fase 2.
            return MockResponse {
                declared_length: Some(body.len() as i64),
                extra: vec![("ETag".into(), format!("\"{etag}\""))],
                ..MockResponse::apk(body[..HALF as usize].to_vec())
            };
        }
        match behavior_second {
            SecondBehavior::Resume206 => {
                let start = req
                    .header("Range")
                    .and_then(|r| {
                        r.trim_start_matches("bytes=")
                            .split('-')
                            .next()
                            .and_then(|s| s.parse::<usize>().ok())
                    })
                    .unwrap_or(0);
                let if_range_ok = req.header("If-Range") == Some(format!("\"{etag}\"").as_str());
                if if_range_ok && start as i64 == HALF {
                    return MockResponse {
                        status: 206,
                        extra: vec![
                            ("ETag".into(), format!("\"{etag}\"")),
                            (
                                "Content-Range".into(),
                                format!("bytes {start}-{}/{}", body.len() - 1, body.len()),
                            ),
                        ],
                        ..MockResponse::apk(body[start..].to_vec())
                    };
                }
                MockResponse::apk(body.clone())
            }
            SecondBehavior::Changed200 => MockResponse::apk(changed(&body)),
            SecondBehavior::Range416 => {
                // n2 (primeiro retry): 416 com Range; n3 (fresh): 500 sem
                // Range para esgotar a fase 1; depois comportamento normal.
                if req.header("Range").is_some() && n == 2 {
                    return MockResponse {
                        status: 416,
                        content_type: "text/plain",
                        body: b"range not satisfiable".to_vec(),
                        declared_length: None,
                        extra: Vec::new(),
                        delay: None,
                        mid_delay: None,
                    };
                }
                if req.header("Range").is_none() && n == 3 {
                    return MockResponse {
                        status: 500,
                        content_type: "text/plain",
                        body: b"boom".to_vec(),
                        declared_length: None,
                        extra: Vec::new(),
                        delay: None,
                        mid_delay: None,
                    };
                }
                if req.header("Range").is_some() {
                    let start = req
                        .header("Range")
                        .and_then(|r| {
                            r.trim_start_matches("bytes=")
                                .split('-')
                                .next()
                                .and_then(|s| s.parse::<usize>().ok())
                        })
                        .unwrap_or(0);
                    return MockResponse {
                        status: 206,
                        extra: vec![(
                            "Content-Range".into(),
                            format!("bytes {start}-{}/{}", body.len() - 1, body.len()),
                        )],
                        ..MockResponse::apk(body[start..].to_vec())
                    };
                }
                MockResponse::apk(body.clone())
            }
        }
    }
}

fn changed(body: &[u8]) -> Vec<u8> {
    let mut novo = body.to_vec();
    for byte in novo.iter_mut().skip(4) {
        *byte = byte.wrapping_add(7);
    }
    novo
}

enum SecondBehavior {
    Resume206,
    Changed200,
    Range416,
}

#[test]
fn queda_no_meio_e_retomada_com_206() {
    let body = fake_apk(FULL as usize);
    let expected = body.clone();
    let for_handler = body.clone();
    let seen = Arc::new(Mutex::new(Vec::new()));
    let handler_seen = Arc::clone(&seen);
    let handler = resume_handler(
        for_handler.clone(),
        "v1",
        SecondBehavior::Resume206,
        Arc::clone(&handler_seen),
    );
    let server = MockServer::start(move |req| handler(req));
    let scratch = ScratchDir::new("resume");
    let dest = scratch.apk();

    // Sessão 1: cai na metade.
    let mut states = Vec::new();
    let mut progress = Vec::new();
    let err = run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).unwrap_err();
    assert!(err.is_retryable(), "{err:?}");
    let meta = ResumeMeta::load(&dest).expect("meta persistida após queda");
    assert_eq!(meta.done, HALF);
    assert_eq!(meta.total, FULL);
    assert!(scratch.part().exists(), "part mantido para retomada");

    // Sessão 2: retoma com Range+If-Range e completa.
    let result =
        run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).expect("retomada ok");
    assert_eq!(result.bytes, FULL);
    assert_eq!(std::fs::read(&dest).expect("arquivo final"), expected);
    assert!(!scratch.part().exists());
    assert!(
        ResumeMeta::load(&dest).is_none(),
        "meta removida ao concluir"
    );

    let requests = seen.lock().unwrap();
    assert!(
        requests[1].contains(&format!("bytes={HALF}-")),
        "retomada deve pedir o intervalo exato: {requests:?}"
    );
    assert!(
        requests[1].contains("v1"),
        "If-Range deve carregar o etag: {requests:?}"
    );
}

#[test]
fn etag_mudou_recomeca_do_zero_e_entrega_arquivo_novo() {
    let body = fake_apk(FULL as usize);
    let for_handler = body.clone();
    let seen = Arc::new(Mutex::new(Vec::new()));
    let handler_seen = Arc::clone(&seen);
    let handler = resume_handler(
        for_handler.clone(),
        "v1",
        SecondBehavior::Changed200,
        Arc::clone(&handler_seen),
    );
    let server = MockServer::start(move |req| handler(req));
    let scratch = ScratchDir::new("etag");
    let dest = scratch.apk();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let err = run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).unwrap_err();
    assert!(err.is_retryable());

    // Sessão 2: If-Range não bate → servidor manda 200 com o arquivo NOVO.
    let result = run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).expect("ok");
    assert_eq!(result.bytes, FULL);
    assert_eq!(
        std::fs::read(&dest).expect("final"),
        changed(&body),
        "arquivo novo, não concatenação"
    );
    assert!(!scratch.part().exists());
}

#[test]
fn range_416_recomeca_do_zero() {
    let body = fake_apk(FULL as usize);
    let expected = body.clone();
    let for_handler = body.clone();
    let seen = Arc::new(Mutex::new(Vec::new()));
    let handler_seen = Arc::clone(&seen);
    let handler = resume_handler(
        for_handler.clone(),
        "v1",
        SecondBehavior::Range416,
        Arc::clone(&handler_seen),
    );
    let server = MockServer::start(move |req| handler(req));
    let scratch = ScratchDir::new("416");
    let dest = scratch.apk();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let err = run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).unwrap_err();
    assert!(err.is_retryable());

    let result =
        run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).expect("ok após 416");
    assert_eq!(result.bytes, FULL);
    assert_eq!(std::fs::read(&dest).expect("final"), expected);
    assert_eq!(
        server.request_count(),
        4,
        "probe + parcial + 416 + fresh completo"
    );
}

#[test]
fn sem_validador_nao_tenta_retomar() {
    let body = fake_apk(FULL as usize);
    let for_handler = body.clone();
    let seen = Arc::new(Mutex::new(Vec::new()));
    let handler_seen = Arc::clone(&seen);
    let counter = Arc::new(AtomicUsize::new(0));
    // Sem ETag: sessão 1 falha na metade; sessão 2 deve vir SEM Range.
    let server = MockServer::start(move |req| {
        let body = &for_handler;
        if is_probe(req) {
            return probe_response(body, "v1");
        }
        handler_seen
            .lock()
            .unwrap()
            .push(format!("range={:?}", req.header("Range")));
        let n = counter.fetch_add(1, Ordering::SeqCst);
        if req.header("Range").is_some() {
            return MockResponse::apk(changed(body));
        }
        if n == 0 {
            MockResponse {
                declared_length: Some(FULL),
                ..MockResponse::apk(body[..HALF as usize].to_vec())
            }
        } else {
            MockResponse::apk(body.clone())
        }
    });
    let scratch = ScratchDir::new("noval");
    let dest = scratch.apk();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let first = run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).unwrap_err();
    assert!(first.is_retryable());
    // Sem validador a meta nem é gravada: não há como armar If-Range.
    assert!(ResumeMeta::load(&dest).is_none());

    let result = run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).expect("fresh ok");
    assert_eq!(result.bytes, FULL);
    let requests = seen.lock().unwrap();
    assert!(
        requests.iter().all(|r| r == "range=None"),
        "nenhuma request deve carregar Range: {requests:?}"
    );
}

#[test]
fn meta_corrompida_recomeca_limpo() {
    let body = fake_apk(FULL as usize);
    let expected = body.clone();
    let server = MockServer::start(move |_| MockResponse::apk(body.clone()));
    let scratch = ScratchDir::new("corrupt");
    let dest = scratch.apk();

    std::fs::write(scratch.part(), b"lixo").unwrap();
    std::fs::write(
        portix_downloader::engine::resume::meta_path(&dest),
        b"v=99\nurl=\n",
    )
    .unwrap();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let result = run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).expect("ok");
    assert_eq!(result.bytes, FULL);
    assert_eq!(std::fs::read(&dest).expect("final"), expected);
    assert!(!scratch.part().exists());
}

#[test]
fn redirect_302_e_seguido_ate_o_apk() {
    let body = fake_apk(FULL as usize);
    let expected = body.clone();
    let server = MockServer::start(move |req| {
        if req.path == "/real.apk" {
            MockResponse::apk(expected.clone())
        } else {
            MockResponse {
                status: 302,
                content_type: "text/plain",
                body: Vec::new(),
                declared_length: Some(0),
                extra: vec![("Location".into(), "/real.apk".into())],
                delay: None,
                mid_delay: None,
            }
        }
    });
    let scratch = ScratchDir::new("redirect");
    let dest = scratch.apk();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let result = run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).expect("ok");
    assert_eq!(result.bytes, FULL);
    assert_eq!(std::fs::read(&dest).expect("final"), body);
}

#[test]
fn cancelamento_no_meio_preserva_progresso_e_retoma() {
    let body = fake_apk(FULL as usize);
    let expected = body.clone();
    let seen = Arc::new(Mutex::new(Vec::new()));
    let handler_seen = Arc::clone(&seen);
    // Sessão 1: manda 64 KiB, pausa 500 ms, mandaria o resto — o teste
    // cancela durante a pausa. Sessão 2: 206 do ponto onde parou.
    let server = MockServer::start(move |req| {
        if is_probe(req) {
            return probe_response(&body, "v1");
        }
        let n = handler_seen.lock().unwrap().len();
        handler_seen
            .lock()
            .unwrap()
            .push(format!("range={:?}", req.header("Range")));
        if n == 0 {
            return MockResponse {
                extra: vec![("ETag".into(), "\"v1\"".into())],
                mid_delay: Some((64 * 1024, Duration::from_millis(500))),
                ..MockResponse::apk(body.clone())
            };
        }
        let start = req
            .header("Range")
            .and_then(|r| {
                r.trim_start_matches("bytes=")
                    .split('-')
                    .next()
                    .and_then(|s| s.parse::<usize>().ok())
            })
            .unwrap_or(0);
        MockResponse {
            status: 206,
            extra: vec![(
                "Content-Range".into(),
                format!("bytes {start}-{}/{}", body.len() - 1, body.len()),
            )],
            ..MockResponse::apk(body[start..].to_vec())
        }
    });
    let scratch = ScratchDir::new("pause");
    let dest = scratch.apk();

    // Cancela 120 ms após o início (durante a pausa do handler).
    let cancel = Arc::new(AtomicBool::new(false));
    let cancel_thread = {
        let cancel_flag = Arc::clone(&cancel);
        std::thread::spawn(move || {
            std::thread::sleep(Duration::from_millis(120));
            cancel_flag.store(true, Ordering::SeqCst);
        })
    };

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let err = run(&server.url, &dest, &cancel, &mut states, &mut progress).unwrap_err();
    cancel_thread.join().unwrap();
    assert_eq!(err.code(), "cancelled", "{err:?}");
    assert!(!dest.exists(), "cancelamento não promove");

    let meta = ResumeMeta::load(&dest).expect("progresso preservado (pausa = retomável)");
    assert!(meta.done >= 64 * 1024, "done={}", meta.done);

    // Retomada completa o arquivo.
    let result = run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).expect("retomada");
    assert_eq!(result.bytes, FULL);
    assert_eq!(std::fs::read(&dest).expect("final"), expected);
}

// ---------------------------------------------------------------------------
// Retry automático (backoff + jitter + Retry-After)
// ---------------------------------------------------------------------------

fn fast_policy(max_attempts: u32) -> retry::RetryPolicy {
    retry::RetryPolicy {
        max_attempts,
        base_delay: Duration::from_millis(20),
        max_delay: Duration::from_millis(60),
        jitter: 0.5,
    }
}

#[test]
fn retry_apos_queda_retoma_e_conclui_sozinho() {
    let body = fake_apk(FULL as usize);
    let for_handler = body.clone();
    let seen = Arc::new(Mutex::new(Vec::new()));
    let handler_seen = Arc::clone(&seen);
    let counter = Arc::new(AtomicUsize::new(0));
    // req1: metade com ETag (queda); req2+: 206 do ponto pedido.
    let server = MockServer::start(move |req| {
        let body = &for_handler;
        if is_probe(req) {
            return probe_response(body, "v1");
        }
        handler_seen
            .lock()
            .unwrap()
            .push(format!("range={:?}", req.header("Range")));
        let n = counter.fetch_add(1, Ordering::SeqCst);
        if n == 0 {
            return MockResponse {
                declared_length: Some(FULL),
                extra: vec![("ETag".into(), "\"v1\"".into())],
                ..MockResponse::apk(body[..HALF as usize].to_vec())
            };
        }
        let start = req
            .header("Range")
            .and_then(|r| {
                r.trim_start_matches("bytes=")
                    .split('-')
                    .next()
                    .and_then(|s| s.parse::<usize>().ok())
            })
            .unwrap_or(0);
        MockResponse {
            status: 206,
            extra: vec![(
                "Content-Range".into(),
                format!("bytes {start}-{}/{}", body.len() - 1, body.len()),
            )],
            ..MockResponse::apk(body[start..].to_vec())
        }
    });
    let scratch = ScratchDir::new("retryresume");
    let dest = scratch.apk();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let result = run_with(
        &server.url,
        &dest,
        &NO_CANCEL,
        &fast_policy(4),
        &mut states,
        &mut progress,
    )
    .expect("retry deve concluir sem intervenção");
    assert_eq!(result.bytes, FULL);
    assert_eq!(std::fs::read(&dest).expect("final"), body);
    let requests = seen.lock().unwrap();
    assert_eq!(requests.len(), 2, "queda + retomada: {requests:?}");
    assert!(
        requests[1].contains(&format!("bytes={HALF}-")),
        "{requests:?}"
    );
}

#[test]
fn retry_apos_500_consegue_200() {
    let body = fake_apk(FULL as usize);
    let counter = Arc::new(AtomicUsize::new(0));
    let server = MockServer::start(move |req| {
        if is_probe(req) {
            return probe_response(&body, "v1");
        }
        let n = counter.fetch_add(1, Ordering::SeqCst);
        if n == 0 {
            MockResponse {
                status: 500,
                content_type: "text/plain",
                body: b"boom".to_vec(),
                declared_length: None,
                extra: Vec::new(),
                delay: None,
                mid_delay: None,
            }
        } else {
            MockResponse::apk(body.clone())
        }
    });
    let scratch = ScratchDir::new("retry500");
    let dest = scratch.apk();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let result = run_with(
        &server.url,
        &dest,
        &NO_CANCEL,
        &fast_policy(3),
        &mut states,
        &mut progress,
    )
    .expect("retry após 500");
    assert_eq!(result.bytes, FULL);
    assert_eq!(
        server.request_count(),
        4,
        "2 probes (1 por tentativa) + 500 + 200"
    );
}

#[test]
fn retry_respeita_retry_after_do_429() {
    let body = fake_apk(64 * 1024);
    let counter = Arc::new(AtomicUsize::new(0));
    let server = MockServer::start(move |_| {
        let n = counter.fetch_add(1, Ordering::SeqCst);
        if n == 0 {
            MockResponse {
                status: 429,
                content_type: "text/plain",
                body: b"lento ai".to_vec(),
                declared_length: None,
                extra: vec![("Retry-After".into(), "1".into())],
                delay: None,
                mid_delay: None,
            }
        } else {
            MockResponse::apk(body.clone())
        }
    });
    let scratch = ScratchDir::new("retry429");
    let dest = scratch.apk();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let began = std::time::Instant::now();
    let result = run_with(
        &server.url,
        &dest,
        &NO_CANCEL,
        &fast_policy(3),
        &mut states,
        &mut progress,
    )
    .expect("retry após 429");
    assert_eq!(result.bytes, 64 * 1024);
    assert!(
        began.elapsed() >= Duration::from_millis(950),
        "Retry-After: 1 deve atrasar a 2ª tentativa ({:?})",
        began.elapsed()
    );
}

#[test]
fn erro_fatal_nao_retrya() {
    let server = MockServer::start(|_| MockResponse {
        status: 404,
        content_type: "text/plain",
        body: b"nope".to_vec(),
        declared_length: None,
        extra: Vec::new(),
        delay: None,
        mid_delay: None,
    });
    let scratch = ScratchDir::new("nofatalretry");
    let dest = scratch.apk();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let err = run_with(
        &server.url,
        &dest,
        &NO_CANCEL,
        &fast_policy(4),
        &mut states,
        &mut progress,
    )
    .unwrap_err();
    assert!(matches!(err, DownloadError::Http { status: 404, .. }));
    assert_eq!(server.request_count(), 1, "404 não merece retry");
}

#[test]
fn cancel_durante_backoff_aborta_rapido() {
    let server = MockServer::start(|_| MockResponse {
        status: 500,
        content_type: "text/plain",
        body: b"boom".to_vec(),
        declared_length: None,
        extra: Vec::new(),
        delay: None,
        mid_delay: None,
    });
    let scratch = ScratchDir::new("cancelbackoff");
    let dest = scratch.apk();

    let cancel = Arc::new(AtomicBool::new(false));
    let thread = {
        let cancel = Arc::clone(&cancel);
        std::thread::spawn(move || {
            std::thread::sleep(Duration::from_millis(60));
            cancel.store(true, Ordering::SeqCst);
        })
    };

    // Política lenta: o backoff seria de ~0,5s-1s entre tentativas.
    let slow = retry::RetryPolicy {
        max_attempts: 6,
        base_delay: Duration::from_millis(500),
        max_delay: Duration::from_secs(8),
        jitter: 0.0,
    };
    let mut states = Vec::new();
    let mut progress = Vec::new();
    let began = std::time::Instant::now();
    let err = run_with(
        &server.url,
        &dest,
        &cancel,
        &slow,
        &mut states,
        &mut progress,
    )
    .unwrap_err();
    thread.join().unwrap();
    assert_eq!(err.code(), "cancelled");
    assert!(
        began.elapsed() < Duration::from_millis(700),
        "{:?}",
        began.elapsed()
    );
}

// ---------------------------------------------------------------------------
// Paralelismo (chunks + probe)
// ---------------------------------------------------------------------------

const BIG: usize = 12 * 1024 * 1024; // 3 chunks de 4 MiB, 3 workers

/// Fatia `bytes=A-B` do corpo como resposta 206.
fn serve_range(req: &MockRequest, body: &[u8], etag: &str) -> MockResponse {
    let (start, end) = req
        .header("Range")
        .and_then(|r| r.trim_start_matches("bytes=").split_once('-'))
        .map(|(a, b)| (a.parse::<u64>().unwrap_or(0), b.parse::<u64>().unwrap_or(0)))
        .unwrap_or((0, 0));
    let end_inclusive = end.min(body.len() as u64 - 1);
    MockResponse {
        status: 206,
        extra: vec![
            (
                "Content-Range".into(),
                format!("bytes {start}-{end_inclusive}/{}", body.len()),
            ),
            ("ETag".into(), format!("\"{etag}\"")),
        ],
        ..MockResponse::apk(body[start as usize..=(end_inclusive as usize)].to_vec())
    }
}

#[test]
fn download_paralelo_monta_o_arquivo_correto() {
    let body = fake_apk(BIG);
    let for_handler = body.clone();
    let server = MockServer::start(move |req| {
        if is_probe(req) {
            return probe_response(&for_handler, "v1");
        }
        serve_range(req, &for_handler, "v1")
    });
    let scratch = ScratchDir::new("par");
    let dest = scratch.apk();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let result = run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).expect("ok");
    assert_eq!(result.bytes, BIG as i64);
    assert_eq!(std::fs::read(&dest).expect("final"), body);
    assert!(!scratch.part().exists());
    assert_eq!(server.request_count(), 4, "probe + 3 chunks");
}

#[test]
fn servidor_sem_range_cai_para_single_stream() {
    let body = fake_apk(BIG);
    let for_handler = body.clone();
    let server = MockServer::start(move |req| {
        let _ = req.header("Range"); // ignora Range deliberadamente
        MockResponse::apk(for_handler.clone())
    });
    let scratch = ScratchDir::new("norange");
    let dest = scratch.apk();

    let mut states = Vec::new();
    let mut progress = Vec::new();
    let result = run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).expect("ok");
    assert_eq!(result.bytes, BIG as i64);
    assert_eq!(std::fs::read(&dest).expect("final"), body);
    assert_eq!(server.request_count(), 2, "probe(200) + stream única");
}

#[test]
fn chunk_cai_no_meio_e_retomada_v2_completa() {
    let body = fake_apk(8 * 1024 * 1024); // 2 chunks de 4 MiB
    let for_handler = body.clone();
    let dropped = Arc::new(AtomicUsize::new(0));
    let dropped_ref = Arc::clone(&dropped);
    let server = MockServer::start(move |req| {
        let body = &for_handler;
        if is_probe(req) {
            return probe_response(body, "v1");
        }
        // Primeira request do chunk 0: metade do intervalo e fecha.
        let range_start = req
            .header("Range")
            .and_then(|r| r.trim_start_matches("bytes=").split('-').next())
            .and_then(|v| v.parse::<u64>().ok());
        if range_start == Some(0) && dropped_ref.fetch_add(1, Ordering::SeqCst) == 0 {
            let end = req
                .header("Range")
                .and_then(|r| r.split('-').nth(1))
                .and_then(|b| b.parse::<usize>().ok())
                .unwrap_or(0);
            let half = end / 2;
            let (start, _) = req
                .header("Range")
                .and_then(|r| r.trim_start_matches("bytes=").split_once('-'))
                .map(|(a, _)| (a.parse::<u64>().unwrap_or(0), 0u64))
                .unwrap_or((0, 0));
            return MockResponse {
                status: 206,
                extra: vec![
                    ("ETag".into(), "\"v1\"".into()),
                    (
                        "Content-Range".into(),
                        format!("bytes {start}-{} {}", half - 1, body.len()),
                    ),
                ],
                declared_length: Some((half - start as usize) as i64),
                ..MockResponse::apk(body[start as usize..half].to_vec())
            };
        }
        serve_range(req, body, "v1")
    });
    let scratch = ScratchDir::new("parresume");
    let dest = scratch.apk();

    // Fase 1: chunk 0 cai no meio → erro retentável, meta v2 no disco.
    let mut states = Vec::new();
    let mut progress = Vec::new();
    let no_retry = retry::RetryPolicy {
        max_attempts: 1,
        ..retry::RetryPolicy::default()
    };
    let err = run_with(
        &server.url,
        &dest,
        &NO_CANCEL,
        &no_retry,
        &mut states,
        &mut progress,
    )
    .unwrap_err();
    assert!(err.is_retryable(), "{err:?}");
    let meta = ResumeMeta::load(&dest).expect("meta v2 persistida");
    let chunks = meta.segments.clone().expect("segmentos na meta");
    assert_eq!(chunks.len(), 2);
    assert!(
        chunks[0].pos > 0 && chunks[0].pos < chunks[0].end,
        "{chunks:?}"
    );
    // Chunk 1 pode ter avançado antes do abort — só precisa ser consistente.
    assert!(
        chunks[1].pos >= chunks[1].start && chunks[1].pos <= chunks[1].end,
        "{chunks:?}"
    );
    assert!(meta.can_resume_parallel(&server.url));

    // Fase 2: retomada paralela conclui o chunk 0 do ponto onde parou.
    let result =
        run(&server.url, &dest, &NO_CANCEL, &mut states, &mut progress).expect("retomada paralela");
    assert_eq!(result.bytes, 8 * 1024 * 1024);
    assert_eq!(std::fs::read(&dest).expect("final"), body);
    assert!(!scratch.part().exists());
    assert!(ResumeMeta::load(&dest).is_none());
}
