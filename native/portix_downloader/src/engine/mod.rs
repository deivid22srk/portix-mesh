//! Núcleo do motor de download, agnóstico de plataforma (sem JNI).
//!
//! Este módulo é deliberadamente testável no host: estados, erros, progresso,
//! escrita atômica e HTTP não conhecem a máquina virtual Java. A ponte JNI
//! (`lib.rs`) apenas adapta. Ver `.ralph/DECISIONS.md` (D3).

pub mod error;
pub mod fsutil;
pub mod http;
pub mod parallel;
pub mod progress;
pub mod resume;
pub mod retry;
pub mod segments;
pub mod state;
pub mod transfer;
