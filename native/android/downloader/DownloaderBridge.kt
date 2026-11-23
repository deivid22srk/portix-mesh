package com.deivid22srk.portix.downloader

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Guarda o EventSink atual para o serviço emitir eventos ao Dart.
 *
 * O motor Rust chama os callbacks numa thread própria; o canal do Flutter
 * exige a thread principal, então os eventos são postados no main looper.
 */
object DownloaderBridge {
    private val main = Handler(Looper.getMainLooper())

    @Volatile
    var events: EventChannel.EventSink? = null

    fun emit(event: Map<String, Any?>) {
        val sink = events ?: return
        main.post { sink.success(event) }
    }
}
