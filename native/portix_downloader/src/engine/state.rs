//! Máquina de estados do download.
//!
//! `Connecting → Downloading → Verifying → Completed`, com saídas para
//! `Failed`/`Cancelled` de qualquer estado ativo. Estados terminais são
//! definitivos. A fila do serviço (Kotlin) adiciona o `Queued` conceitual
//! antes do motor assumir.

/// Estado de um download no motor.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DownloadState {
    /// Resolvendo/abrindo a conexão (inclui probe de capacidade no futuro).
    Connecting,
    /// Transferindo bytes.
    Downloading,
    /// Validação final (magic, tamanho, hash no futuro).
    Verifying,
    /// Arquivo renomeado para o destino final. Terminal.
    Completed,
    /// Erro definitivo após retries. Terminal.
    Failed,
    /// Cancelado pelo usuário. Terminal.
    Cancelled,
}

impl DownloadState {
    pub fn is_terminal(self) -> bool {
        matches!(
            self,
            DownloadState::Completed | DownloadState::Failed | DownloadState::Cancelled
        )
    }
}

/// Rastro da transição inválida (para diagnóstico/testes).
#[derive(Debug, PartialEq, Eq)]
pub struct InvalidTransition {
    pub from: DownloadState,
    pub to: DownloadState,
}

/// Guarda o estado atual e valida transições.
#[derive(Debug)]
pub struct StateTracker {
    current: DownloadState,
}

impl StateTracker {
    /// Estado inicial do motor: conectando.
    pub fn new() -> Self {
        Self {
            current: DownloadState::Connecting,
        }
    }

    pub fn current(&self) -> DownloadState {
        self.current
    }

    /// Transição validada. Transição para o mesmo estado é no-op válido.
    pub fn transition(&mut self, to: DownloadState) -> Result<(), InvalidTransition> {
        if self.current == to {
            return Ok(());
        }
        if self.current.is_terminal() || !Self::allowed(self.current, to) {
            return Err(InvalidTransition {
                from: self.current,
                to,
            });
        }
        self.current = to;
        Ok(())
    }

    fn allowed(from: DownloadState, to: DownloadState) -> bool {
        use DownloadState::*;
        matches!(
            (from, to),
            (Connecting, Downloading)
                | (Connecting, Failed)
                | (Connecting, Cancelled)
                | (Downloading, Verifying)
                | (Downloading, Failed)
                | (Downloading, Cancelled)
                | (Verifying, Completed)
                | (Verifying, Failed)
                | (Verifying, Cancelled)
        )
    }
}

impl Default for StateTracker {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn caminho_feliz_completo() {
        let mut s = StateTracker::new();
        assert_eq!(s.current(), DownloadState::Connecting);
        s.transition(DownloadState::Downloading).unwrap();
        s.transition(DownloadState::Verifying).unwrap();
        s.transition(DownloadState::Completed).unwrap();
        assert!(s.current().is_terminal());
    }

    #[test]
    fn falhas_a_partir_de_qualquer_estado_ativo() {
        for fail_from in [
            DownloadState::Connecting,
            DownloadState::Downloading,
            DownloadState::Verifying,
        ] {
            let mut s = StateTracker::new();
            // avança até fail_from
            for step in [DownloadState::Downloading, DownloadState::Verifying] {
                if step == fail_from {
                    break;
                }
                s.transition(step).unwrap();
            }
            s.transition(DownloadState::Failed).unwrap();
            assert!(s.current().is_terminal());
        }
    }

    #[test]
    fn terminais_sao_trancados() {
        for terminal in [
            DownloadState::Completed,
            DownloadState::Failed,
            DownloadState::Cancelled,
        ] {
            let mut s = StateTracker::new();
            s.transition(DownloadState::Downloading).unwrap();
            s.transition(DownloadState::Verifying).unwrap();
            s.transition(terminal).unwrap();
            // Do terminal, nenhuma transição para estado DIFERENTE é
            // permitida (repetir o próprio terminal é no-op).
            let others = [
                DownloadState::Connecting,
                DownloadState::Downloading,
                DownloadState::Verifying,
                DownloadState::Completed,
                DownloadState::Failed,
                DownloadState::Cancelled,
            ];
            for other in others.iter().filter(|state| **state != terminal) {
                assert!(
                    s.transition(*other).is_err(),
                    "{terminal:?} → {other:?} deveria falhar"
                );
            }
            assert_eq!(s.current(), terminal);
        }
    }

    #[test]
    fn pulo_de_estado_e_rejeitado() {
        let mut s = StateTracker::new();
        assert_eq!(
            s.transition(DownloadState::Completed),
            Err(InvalidTransition {
                from: DownloadState::Connecting,
                to: DownloadState::Completed
            })
        );
        let mut s = StateTracker::new();
        s.transition(DownloadState::Downloading).unwrap();
        assert!(s.transition(DownloadState::Completed).is_err());
    }

    #[test]
    fn mesmo_estado_e_noop() {
        let mut s = StateTracker::new();
        s.transition(DownloadState::Connecting).unwrap();
        assert_eq!(s.current(), DownloadState::Connecting);
    }
}
