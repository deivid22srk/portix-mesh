package com.deivid22srk.portix.downloader

/**
 * Callback chamado pelo motor Rust numa thread própria.
 *
 * Contrato (estável — códigos espelham `engine::state` no Rust):
 * - [onProgress] legado, a ~3/s (notificação).
 * - [onStats] rico, a ~10/s (UI: velocidade/ETA; `etaSecs = -1` = desconhecido).
 * - [onState] transições com os códigos [STATE_CONNECTING]…[STATE_CANCELLED].
 * - [onComplete] termina a sessão; `error` segue `"<code>|<detalhe>"`.
 */
interface DownloadCallback {
    companion object {
        const val STATE_CONNECTING = 0
        const val STATE_DOWNLOADING = 1
        const val STATE_VERIFYING = 2
        const val STATE_COMPLETED = 3
        const val STATE_FAILED = 4
        const val STATE_CANCELLED = 5
    }

    fun onProgress(done: Long, total: Long)
    fun onStats(done: Long, total: Long, speedBps: Double, etaSecs: Long)
    fun onState(state: Int)
    fun onComplete(ok: Boolean, error: String?)
}
