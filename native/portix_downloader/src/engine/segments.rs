//! Planejamento de segmentos para download paralelo.
//!
//! Balanceamento por **oversubscription**: o plano cria mais chunks do que
//! conexões (2×); quem termina o chunk pega o próximo da fila. Servidores
//! lentos em um intervalo não estrangulam o conjunto — o efeito é o mesmo
//! do work-stealing, sem coordenação em pleno voo.

/// Chunk de trabalho: intervalo `[pos, end)` com progresso.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ChunkState {
    /// Primeiro byte do intervalo no arquivo final.
    pub start: u64,
    /// Byte final **exclusivo**.
    pub end: u64,
    /// Próximo byte a baixar.
    pub pos: u64,
}

impl ChunkState {
    pub fn new(start: u64, end: u64) -> Self {
        Self {
            start,
            end,
            pos: start,
        }
    }

    pub fn remaining(&self) -> u64 {
        self.end.saturating_sub(self.pos)
    }

    pub fn is_done(&self) -> bool {
        self.pos >= self.end
    }
}

/// Conexões máximas do motor.
pub const MAX_CONNECTIONS: usize = 8;
/// Multiplicador de chunks por conexão (fila de balanceamento).
pub const CHUNKS_PER_WORKER: usize = 2;
/// Menor tamanho de arquivo que justifica paralelismo.
pub const PARALLEL_MIN_BYTES: u64 = 8 * 1024 * 1024;
/// Tamanho alvo de cada chunk na divisão inicial.
const TARGET_CHUNK_BYTES: u64 = 4 * 1024 * 1024;
/// Chunk nunca menor que isso (evita pulverizar).
pub const MIN_CHUNK_BYTES: u64 = 1024 * 1024;

/// Conexões simultâneas para `total` bytes (1 = single-stream).
pub fn worker_count(total: i64) -> usize {
    if total < PARALLEL_MIN_BYTES as i64 {
        return 1;
    }
    let chunks = chunk_count(total);
    chunks.min(MAX_CONNECTIONS)
}

/// Quantidade de chunks para dividir `total` (>= workers).
pub fn chunk_count(total: i64) -> usize {
    if total < PARALLEL_MIN_BYTES as i64 {
        return 1;
    }
    let total = total as u64;
    let by_target = (total / TARGET_CHUNK_BYTES) as usize;
    let by_size_floor = (total / MIN_CHUNK_BYTES) as usize;
    by_target
        .max(1)
        .min(by_size_floor.max(1))
        .min(MAX_CONNECTIONS * CHUNKS_PER_WORKER)
}

/// Divide `[0, total)` em chunks quase iguais e ordenados.
pub fn plan_chunks(total: i64) -> Vec<ChunkState> {
    if total <= 0 {
        return vec![ChunkState::new(0, 0)];
    }
    let total = total as u64;
    let n = chunk_count(total as i64) as u64;
    let n = n.min(total).max(1);
    let base = total / n;
    let rest = total % n;
    let mut chunks = Vec::with_capacity(n as usize);
    let mut start = 0u64;
    for i in 0..n {
        let len = base + if i < rest { 1 } else { 0 };
        chunks.push(ChunkState::new(start, start + len));
        start += len;
    }
    chunks
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn arquivos_pequenos_usam_single_stream() {
        assert_eq!(worker_count(0), 1);
        assert_eq!(worker_count((8 * 1024 * 1024 - 1) as i64), 1);
        assert!(worker_count((64 * 1024 * 1024) as i64) > 1);
        assert!(worker_count(2 * 1024 * 1024 * 1024i64) <= MAX_CONNECTIONS);
    }

    #[test]
    fn plan_cobre_exatamente_o_total_sem_buracos() {
        for total in [0i64, 1, 1023, 8 * 1024 * 1024, 9_999_999, 1 << 30] {
            let chunks = plan_chunks(total);
            let covered: u64 = chunks.iter().map(|c| c.remaining()).sum();
            assert_eq!(covered, total.max(0) as u64, "total={total}");
            for pair in chunks.windows(2) {
                assert_eq!(pair[0].end, pair[1].pos, "total={total}");
            }
            assert!(chunks.iter().all(|c| c.pos <= c.end));
        }
    }

    #[test]
    fn plan_com_um_byte_nao_explode() {
        let chunks = plan_chunks(1);
        assert_eq!(chunks.len(), 1);
        assert_eq!(chunks[0].remaining(), 1);
    }

    #[test]
    fn chunks_superiores_as_conexoes_para_balancear() {
        let total = 64 * 1024 * 1024;
        assert!(chunk_count(total) > worker_count(total));
        assert!(worker_count(total) <= MAX_CONNECTIONS);
    }
}
