//! Erros tipados do motor com códigos estáveis.
//!
//! O contrato na fronteira é `"<code>|<detalhe legível>"`. O `code` é estável
//! e será mapeado para mensagens localizadas no Dart (pt/en); o detalhe é
//! apenas para diagnóstico. Classificação `retentável` guiará o retry (P1).

use std::fmt;

/// Erro de download. `code()` nunca muda de significado (contrato estável).
#[derive(Debug)]
pub enum DownloadError {
    /// URL vazia, sem esquema http(s) ou não parseável.
    InvalidUrl,
    /// Caminho de destino inseguro (vazio, `..`, sem nome de arquivo).
    InvalidDestination(String),
    /// Falha de transporte (DNS, conexão, timeout, leitura interrompida).
    Network(String),
    /// Resposta HTTP com status de erro. `retry_after_secs` vem do header
    /// `Retry-After` quando presente (429/503).
    Http {
        status: u16,
        retry_after_secs: Option<u64>,
    },
    /// O arquivo remoto mudou desde o início (validadores divergentes).
    FileChanged,
    /// Servidor recusou o intervalo pedido (416) — retomada inválida.
    RangeNotSatisfiable,
    /// Erro de sistema de arquivos genérico.
    Io(String),
    /// Espaço em disco insuficiente (pré-checagem ou ENOSPC na escrita).
    DiskFull,
    /// Conteúdo não é um APK (`content_type` rejeitado ou *magic* ausente).
    NotAnApk(&'static str),
    /// Stream encerrada antes de atingir `Content-Length`.
    Truncated { done: i64, total: i64 },
    /// Cancelamento cooperativo (não é falha).
    Cancelled,
    /// Pânico/estado inconsistente capturado na fronteira.
    Internal(String),
}

impl DownloadError {
    /// Código estável para o contrato JNI → Dart.
    pub fn code(&self) -> &'static str {
        match self {
            DownloadError::InvalidUrl => "invalid_url",
            DownloadError::InvalidDestination(_) => "invalid_destination",
            DownloadError::Network(_) => "network",
            DownloadError::Http { .. } => "http_status",
            DownloadError::FileChanged => "file_changed",
            DownloadError::RangeNotSatisfiable => "range_not_satisfiable",
            DownloadError::Io(_) => "io",
            DownloadError::DiskFull => "disk_full",
            DownloadError::NotAnApk(_) => "not_apk",
            DownloadError::Truncated { .. } => "truncated",
            DownloadError::Cancelled => "cancelled",
            DownloadError::Internal(_) => "internal",
        }
    }

    /// Se vale a pena tentar de novo (uso futuro pelo retry com backoff).
    pub fn is_retryable(&self) -> bool {
        match self {
            DownloadError::Network(_) => true,
            DownloadError::Http { status, .. } => *status >= 500 || *status == 429,
            DownloadError::RangeNotSatisfiable | DownloadError::FileChanged => true,
            DownloadError::Truncated { .. } => true,
            // Disco cheio e 4xx definitivos não melhoram com retry imediato.
            _ => false,
        }
    }
}

impl fmt::Display for DownloadError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            DownloadError::InvalidUrl => write!(f, "URL inválida"),
            DownloadError::InvalidDestination(d) => write!(f, "destino inválido: {d}"),
            DownloadError::Network(d) => write!(f, "falha de rede: {d}"),
            DownloadError::Http { status, .. } => write!(f, "resposta HTTP {status}"),
            DownloadError::FileChanged => write!(f, "o arquivo remoto mudou"),
            DownloadError::RangeNotSatisfiable => {
                write!(f, "intervalo não suportado pelo servidor")
            }
            DownloadError::Io(d) => write!(f, "erro de disco: {d}"),
            DownloadError::DiskFull => write!(f, "espaço em disco insuficiente"),
            DownloadError::NotAnApk(reason) => write!(f, "o arquivo não é um APK ({reason})"),
            DownloadError::Truncated { done, total } => {
                write!(f, "download truncado ({done}/{total} bytes)")
            }
            DownloadError::Cancelled => write!(f, "download cancelado"),
            DownloadError::Internal(d) => write!(f, "falha interna: {d}"),
        }
    }
}

impl std::error::Error for DownloadError {}

/// Serializa para o formato do contrato: `"<code>|<detalhe>"`.
pub fn wire_message(error: &DownloadError) -> String {
    format!("{}|{error}", error.code())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn codigos_sao_estaveis_e_distintos() {
        let errors: Vec<DownloadError> = vec![
            DownloadError::InvalidUrl,
            DownloadError::InvalidDestination("x".into()),
            DownloadError::Network("timeout".into()),
            DownloadError::Http {
                status: 404,
                retry_after_secs: None,
            },
            DownloadError::FileChanged,
            DownloadError::RangeNotSatisfiable,
            DownloadError::Io("perm".into()),
            DownloadError::DiskFull,
            DownloadError::NotAnApk("magic"),
            DownloadError::Truncated { done: 1, total: 2 },
            DownloadError::Cancelled,
            DownloadError::Internal("panico".into()),
        ];
        let mut codes: Vec<&str> = errors.iter().map(|e| e.code()).collect();
        codes.sort_unstable();
        let initial_len = codes.len();
        codes.dedup();
        assert_eq!(codes.len(), initial_len, "códigos devem ser únicos");
        assert_eq!(errors[0].code(), "invalid_url");
        assert_eq!(errors[7].code(), "disk_full");
        assert_eq!(errors[10].code(), "cancelled");
    }

    #[test]
    fn classificacao_de_retry() {
        assert!(DownloadError::Network("reset".into()).is_retryable());
        assert!(DownloadError::Http {
            status: 503,
            retry_after_secs: None
        }
        .is_retryable());
        assert!(DownloadError::Http {
            status: 429,
            retry_after_secs: Some(30)
        }
        .is_retryable());
        assert!(DownloadError::Truncated {
            done: 10,
            total: 20
        }
        .is_retryable());
        assert!(DownloadError::RangeNotSatisfiable.is_retryable());
        assert!(!DownloadError::Http {
            status: 404,
            retry_after_secs: None
        }
        .is_retryable());
        assert!(!DownloadError::DiskFull.is_retryable());
        assert!(!DownloadError::NotAnApk("magic").is_retryable());
        assert!(!DownloadError::Cancelled.is_retryable());
        assert!(!DownloadError::InvalidUrl.is_retryable());
    }

    #[test]
    fn wire_message_tem_formato_code_pipe() {
        let e = DownloadError::Http {
            status: 404,
            retry_after_secs: None,
        };
        let msg = wire_message(&e);
        assert_eq!(msg, "http_status|resposta HTTP 404");
        assert!(msg.split_once('|').is_some());
    }
}
