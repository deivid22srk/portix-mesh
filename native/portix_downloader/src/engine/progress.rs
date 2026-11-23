//! Progresso com velocidade suavizada (EWMA) e ETA estável.
//!
//! Amostragem interna rápida e emissão throttled para a UI não tremer.
//! O contrato enriquecido (velocidade/ETA no JNI) chega na iteração de
//! contrato; aqui o dado já é produzido e testado.

use std::time::{Duration, Instant};

/// Amostra de progresso pronta para consumo.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ProgressEvent {
    pub done: i64,
    pub total: i64,
    /// Velocidade suavizada em bytes/s (EWMA).
    pub speed_bps: f64,
    /// ETA em segundos, quando `total` é conhecido e há velocidade mensurável.
    pub eta_secs: Option<u64>,
}

/// Acumulador de progresso. `sample` retorna `Some` só quando vale emitir.
#[derive(Debug)]
pub struct ProgressTracker {
    interval: Duration,
    min_sample: Duration,
    last_emit: Option<Instant>,
    last_sample: Option<(Instant, i64)>,
    ewma: f64,
    alpha: f64,
}

impl ProgressTracker {
    /// `interval` é o tempo mínimo entre emissões (throttle da UI).
    pub fn new(interval: Duration) -> Self {
        Self {
            interval,
            // Amostras mais rápidas que isso não melhoram a estimativa.
            min_sample: Duration::from_millis(40),
            last_emit: None,
            last_sample: None,
            ewma: 0.0,
            alpha: 0.25,
        }
    }

    /// Registra `done/total` no instante `now`. `force` emite mesmo dentro do
    /// throttle (usado no fim da transferência).
    pub fn sample(
        &mut self,
        done: i64,
        total: i64,
        now: Instant,
        force: bool,
    ) -> Option<ProgressEvent> {
        match self.last_sample {
            None => {
                self.last_sample = Some((now, done));
                self.last_emit = Some(now);
                None
            }
            Some((last_time, last_done)) => {
                let dt = now.duration_since(last_time);
                // `force` (fim da transferência) ignora a janela mínima de
                // amostragem para garantir o evento final em 100%.
                if !force && dt < self.min_sample {
                    return None;
                }
                let instant = (done - last_done).max(0) as f64 / dt.as_secs_f64().max(f64::EPSILON);
                self.ewma = if self.ewma <= f64::EPSILON {
                    instant
                } else {
                    self.alpha * instant + (1.0 - self.alpha) * self.ewma
                };
                self.last_sample = Some((now, done));

                let throttled = self
                    .last_emit
                    .is_some_and(|t| now.duration_since(t) < self.interval);
                if !force && throttled {
                    return None;
                }
                self.last_emit = Some(now);

                let eta_secs = if total > 0 && done <= total && self.ewma > 1.0 {
                    Some(((total - done) as f64 / self.ewma) as u64)
                } else {
                    None
                };
                Some(ProgressEvent {
                    done,
                    total,
                    speed_bps: self.ewma,
                    eta_secs,
                })
            }
        }
    }

    /// Velocidade suavizada atual (bytes/s), para testes e diagnóstico.
    pub fn speed(&self) -> f64 {
        self.ewma
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tracker() -> ProgressTracker {
        ProgressTracker::new(Duration::from_millis(100))
    }

    #[test]
    fn primeira_amostra_nao_emite() {
        let mut t = tracker();
        let t0 = Instant::now();
        assert!(t.sample(0, 1000, t0, false).is_none());
    }

    #[test]
    fn throttle_suprime_ate_intervalo() {
        let mut t = tracker();
        let t0 = Instant::now();
        assert!(t.sample(0, 100_000, t0, false).is_none());
        // 50ms depois: abaixo do intervalo de 100ms → nada.
        assert!(t
            .sample(4_000, 100_000, t0 + Duration::from_millis(50), false)
            .is_none());
        // 120ms depois do início: passa do intervalo → emite.
        let ev = t.sample(12_000, 100_000, t0 + Duration::from_millis(120), false);
        assert!(ev.is_some());
        let ev = ev.unwrap();
        assert_eq!(ev.done, 12_000);
        assert_eq!(ev.total, 100_000);
        assert!(ev.speed_bps > 0.0);
        assert!(ev.eta_secs.is_some());
    }

    #[test]
    fn force_emite_no_fim() {
        let mut t = tracker();
        let t0 = Instant::now();
        assert!(t.sample(0, 1000, t0, false).is_none());
        let ev = t.sample(1000, 1000, t0 + Duration::from_millis(50), true);
        assert!(ev.is_some());
        assert_eq!(ev.unwrap().eta_secs, Some(0));
    }

    #[test]
    fn total_desconhecido_nao_tem_eta() {
        let mut t = tracker();
        let t0 = Instant::now();
        assert!(t.sample(0, -1, t0, false).is_none());
        let ev = t
            .sample(8_000, -1, t0 + Duration::from_millis(200), true)
            .unwrap();
        assert_eq!(ev.total, -1);
        assert!(ev.eta_secs.is_none());
        assert!(ev.speed_bps > 0.0);
    }
}
