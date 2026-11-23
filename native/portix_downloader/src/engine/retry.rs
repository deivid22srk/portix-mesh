//! Retry com backoff exponencial, jitter e `Retry-After`.
//!
//! Políticas:
//! - Só retrya erros classificados como retentáveis (`is_retryable()`).
//! - Backoff exponencial com teto e jitter multiplicativo (evita sincronizar
//!   clientes). PRNG xorshift64\* semeado pelo relógio — zero dependências.
//! - `Retry-After` (429/503) vence o backoff calculado quando maior.
//! - Cancelamento interrompe a espera em ≤100 ms.
//! - Cada retry reaproveita a retomada do disco (`.part.meta`) automaticamente.

use std::time::Duration;

/// Política de retry usada pelo motor.
#[derive(Debug, Clone, Copy)]
pub struct RetryPolicy {
    /// Total de tentativas (incluindo a primeira). 1 = sem retry.
    pub max_attempts: u32,
    /// Atraso base do backoff (dobra a cada tentativa).
    pub base_delay: Duration,
    /// Teto do atraso calculado (antes do `Retry-After`).
    pub max_delay: Duration,
    /// Jitter multiplicativo: atraso ∈ [d·(1−j), d·(1+j)].
    pub jitter: f64,
}

impl Default for RetryPolicy {
    fn default() -> Self {
        Self {
            max_attempts: 4,
            base_delay: Duration::from_millis(500),
            max_delay: Duration::from_secs(8),
            jitter: 0.5,
        }
    }
}

/// PRNG xorshift64\* determinístico por seed (testável).
#[derive(Debug)]
pub struct RetryRng(u64);

impl RetryRng {
    /// Seed a partir do relógio (nanos desde a época).
    pub fn from_clock() -> Self {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos() as u64)
            .unwrap_or(0x9E3779B97F4A7C15);
        RetryRng(nanos | 1)
    }

    #[cfg(test)]
    pub fn seeded(seed: u64) -> Self {
        RetryRng(seed | 1)
    }

    /// Próximo u64 pseudoaleatório (xorshift64\*).
    pub fn next_u64(&mut self) -> u64 {
        let mut x = self.0;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.0 = x;
        x.wrapping_mul(0x2545F4914F6CDD1D)
    }

    /// Uniforme em [0, 1).
    pub fn next_f64(&mut self) -> f64 {
        (self.next_u64() >> 11) as f64 / (1u64 << 53) as f64
    }
}

/// Atraso para a tentativa `attempt` (1-based) com a política dada.
///
/// `d(attempt) = clamp(base·2^(attempt−1), max)` com jitter multiplicativo.
pub fn delay_for(policy: &RetryPolicy, attempt: u32, rng: &mut RetryRng) -> Duration {
    let exp = attempt.saturating_sub(1).min(16);
    let raw = policy.base_delay.as_secs_f64() * 2f64.powi(exp as i32);
    let clamped = raw.min(policy.max_delay.as_secs_f64());
    let j = policy.jitter.clamp(0.0, 1.0);
    let factor = 1.0 + (2.0 * rng.next_f64() - 1.0) * j;
    Duration::from_secs_f64((clamped * factor).max(0.0))
}

/// Atraso efetivo considerando `Retry-After` (segundos) do servidor.
pub fn effective_delay(
    policy: &RetryPolicy,
    attempt: u32,
    retry_after_secs: Option<u64>,
    rng: &mut RetryRng,
) -> Duration {
    let computed = delay_for(policy, attempt, rng);
    match retry_after_secs {
        Some(secs) => computed.max(Duration::from_secs(secs)),
        None => computed,
    }
}

/// Dorme o atraso em fatias de ~100 ms, retornando `false` se cancelado.
pub fn sleep_interruptible(total: Duration, cancel: &std::sync::atomic::AtomicBool) -> bool {
    use std::sync::atomic::Ordering;
    use std::time::Instant;
    let start = Instant::now();
    loop {
        if cancel.load(Ordering::SeqCst) {
            return false;
        }
        let elapsed = start.elapsed();
        if elapsed >= total {
            return true;
        }
        let remaining = total - elapsed;
        std::thread::sleep(remaining.min(Duration::from_millis(100)));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn policy() -> RetryPolicy {
        RetryPolicy {
            max_attempts: 4,
            base_delay: Duration::from_millis(500),
            max_delay: Duration::from_secs(8),
            jitter: 0.5,
        }
    }

    #[test]
    fn backoff_cresce_e_respeita_teto() {
        let p = policy();
        let mut rng = RetryRng::seeded(42);
        let mid = delay_for(&p, 1, &mut rng).as_secs_f64(); // ~0.5s ±50%
        assert!((0.24..=0.76).contains(&mid), "attempt1: {mid}");
        let d4 = delay_for(&p, 4, &mut rng).as_secs_f64(); // ~4s ±50%
        assert!((1.9..=6.1).contains(&d4), "attempt4: {d4}");
        let d9 = delay_for(&p, 9, &mut rng).as_secs_f64(); // clampado a 8s ±50%
        assert!((3.9..=12.1).contains(&d9), "teto com jitter: {d9}");
    }

    #[test]
    fn rng_semeado_e_deterministico() {
        let mut a = RetryRng::seeded(7);
        let mut b = RetryRng::seeded(7);
        for _ in 0..8 {
            assert_eq!(a.next_u64(), b.next_u64());
        }
        assert_ne!(a.next_f64(), a.next_f64());
    }

    #[test]
    fn retry_after_vence_backoff() {
        let p = policy();
        let mut rng = RetryRng::seeded(9);
        let d = effective_delay(&p, 1, Some(30), &mut rng);
        assert_eq!(d, Duration::from_secs(30));
        let d = effective_delay(&p, 1, Some(0), &mut rng);
        assert!(
            d >= Duration::from_millis(250) && d <= Duration::from_millis(750),
            "{d:?}"
        );
    }

    #[test]
    fn sleep_interruptivel_aborta_no_cancel() {
        use std::sync::atomic::{AtomicBool, Ordering};
        let cancel = std::sync::Arc::new(AtomicBool::new(false));
        let handle = {
            let cancel = std::sync::Arc::clone(&cancel);
            std::thread::spawn(move || {
                std::thread::sleep(Duration::from_millis(80));
                cancel.store(true, Ordering::SeqCst);
            })
        };
        let began = std::time::Instant::now();
        let completed = sleep_interruptible(Duration::from_secs(5), &cancel);
        handle.join().unwrap();
        assert!(!completed, "espera deve abortar");
        assert!(began.elapsed() < Duration::from_secs(1));
    }

    #[test]
    fn sleep_completo_quando_nao_cancela() {
        use std::sync::atomic::AtomicBool;
        let cancel = AtomicBool::new(false);
        let began = std::time::Instant::now();
        assert!(sleep_interruptible(Duration::from_millis(60), &cancel));
        assert!(began.elapsed() >= Duration::from_millis(55));
    }
}
