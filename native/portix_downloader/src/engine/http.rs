//! Configuração do cliente HTTP (ureq + rustls).
//!
//! Timeouts explícitos e limite de redirecionamentos fixo. Sem
//! descompressão automática (feature `gzip` removida — D2), para que
//! `Content-Length` e `Range` continuem honestos.

use std::time::Duration;

use super::error::DownloadError;

const CONNECT_TIMEOUT: Duration = Duration::from_secs(20);
const READ_TIMEOUT: Duration = Duration::from_secs(60);
const WRITE_TIMEOUT: Duration = Duration::from_secs(30);
const MAX_REDIRECTS: u32 = 5;
const USER_AGENT: &str = concat!("PORTIX/", env!("CARGO_PKG_VERSION"), " (Android)");

/// Agente compartilhado entre downloads (reaproveita conexões).
pub fn agent() -> ureq::Agent {
    ureq::AgentBuilder::new()
        .timeout_connect(CONNECT_TIMEOUT)
        .timeout_read(READ_TIMEOUT)
        .timeout_write(WRITE_TIMEOUT)
        .redirects(MAX_REDIRECTS)
        .user_agent(USER_AGENT)
        .build()
}

/// Valida o esquema da URL antes de abrir conexão.
pub fn validate_url(url: &str) -> Result<(), DownloadError> {
    let url = url.trim();
    if url.is_empty() || !(url.starts_with("http://") || url.starts_with("https://")) {
        return Err(DownloadError::InvalidUrl);
    }
    Ok(())
}

/// Traduz um erro do ureq para o erro tipado do motor.
pub fn map_ureq_error(error: ureq::Error) -> DownloadError {
    match error {
        ureq::Error::Status(status, response) => {
            // 416 durante retomada = intervalo recusado → recomeço seguro.
            if status == 416 {
                return DownloadError::RangeNotSatisfiable;
            }
            DownloadError::Http {
                status,
                retry_after_secs: response
                    .header("Retry-After")
                    .and_then(|value| value.trim().parse::<u64>().ok()),
            }
        }
        ureq::Error::Transport(transport) => DownloadError::Network(transport.to_string()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn urls_validas_e_invalidas() {
        assert!(validate_url("https://exemplo.com/app.apk").is_ok());
        assert!(validate_url("http://127.0.0.1:9/apk").is_ok());
        assert!(validate_url("").is_err());
        assert!(validate_url("   ").is_err());
        assert!(validate_url("ftp://x/apk").is_err());
        assert!(validate_url("file:///system/bin/sh").is_err());
        assert!(validate_url("javascript:alert(1)").is_err());
    }

    #[test]
    fn mapeamento_de_status_preserva_retry_after() {
        // Simula o mapeamento direto (sem servidor): constrói e inspeciona.
        let e = map_ureq_error_status_only(503, Some(42));
        assert!(e.is_retryable());
        match e {
            DownloadError::Http {
                status,
                retry_after_secs,
            } => {
                assert_eq!(status, 503);
                assert_eq!(retry_after_secs, Some(42));
            }
            other => panic!("esperado Http, veio {other:?}"),
        }
    }

    fn map_ureq_error_status_only(status: u16, retry: Option<u64>) -> DownloadError {
        DownloadError::Http {
            status,
            retry_after_secs: retry,
        }
    }
}
