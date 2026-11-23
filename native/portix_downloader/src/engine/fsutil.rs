//! Utilidades de sistema de arquivos: sanitização, espaço em disco, cleanup.

use std::io;
use std::path::{Path, PathBuf};

use super::error::DownloadError;

const ENOSPC: i32 = 28;

/// Rejeita destinos inseguros: vazio, sem nome de arquivo, com `..` em
/// qualquer componente ou nome de arquivo `.`/`..` (defesa em profundidade —
/// o destino vem do nosso Kotlin, mas o motor não confia).
pub fn sanitize_destination(dest: &Path) -> Result<(), DownloadError> {
    if dest.as_os_str().is_empty() {
        return Err(DownloadError::InvalidDestination("caminho vazio".into()));
    }
    for component in dest.components() {
        if matches!(component, std::path::Component::ParentDir) {
            return Err(DownloadError::InvalidDestination(
                "caminho contém `..`".into(),
            ));
        }
    }
    match dest.file_name() {
        None => Err(DownloadError::InvalidDestination(
            "sem nome de arquivo".into(),
        )),
        Some(name) => {
            let name = name.to_string_lossy();
            if name == "." || name == ".." {
                return Err(DownloadError::InvalidDestination(format!(
                    "nome inválido: {name}"
                )));
            }
            Ok(())
        }
    }
}

/// Espaço disponível para o usuário no ponto montado de `path` (bytes).
/// `None` quando não é possível medir (plataforma/erro) — a chamada vira no-op.
pub fn usable_space(path: &Path) -> Option<u64> {
    let text = path.as_os_str().to_str()?;
    let c_path = std::ffi::CString::new(text).ok()?;
    let mut stat: libc::statvfs = unsafe { std::mem::zeroed() };
    // SAFETY: ponteiro válido para um `statvfs` alocado e path CString válido.
    let rc = unsafe { libc::statvfs(c_path.as_ptr(), &mut stat) };
    if rc != 0 {
        return None;
    }
    Some(stat.f_bavail as u64 * stat.f_frsize as u64)
}

/// Mapeia um `io::Error` para o erro tipado, detectando disco cheio (ENOSPC).
pub fn io_error(error: io::Error) -> DownloadError {
    if error.raw_os_error() == Some(ENOSPC) {
        return DownloadError::DiskFull;
    }
    DownloadError::Io(error.to_string())
}

/// Caminho do arquivo parcial (`.part`) para o destino final.
pub fn part_path(dest: &Path) -> PathBuf {
    let mut os = dest.as_os_str().to_os_string();
    os.push(".part");
    PathBuf::from(os)
}

/// Remove o arquivo se existir; ignora falhas (cleanup best-effort).
pub fn remove_if_exists(path: &Path) {
    let _ = std::fs::remove_file(path);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn destinos_validos_passam() {
        assert!(sanitize_destination(Path::new("/data/app/portix-1.apk")).is_ok());
        assert!(sanitize_destination(Path::new("/tmp/a/b/c.apk")).is_ok());
    }

    #[test]
    fn path_traversal_e_rejeitado() {
        assert!(sanitize_destination(Path::new("")).is_err());
        assert!(sanitize_destination(Path::new("/data/../etc/passwd.apk")).is_err());
        assert!(sanitize_destination(Path::new("rel/../../subindo.apk")).is_err());
        assert!(sanitize_destination(Path::new("..")).is_err());
        assert!(sanitize_destination(Path::new(".")).is_err());
    }

    #[test]
    fn parte_path_anexa_sufixo() {
        let part = part_path(Path::new("/x/portix-3.apk"));
        assert_eq!(part, PathBuf::from("/x/portix-3.apk.part"));
    }

    #[test]
    fn espaco_em_disco_em_unix() {
        let space = usable_space(Path::new("/tmp"));
        assert!(space.is_some_and(|s| s > 0));
    }
}
