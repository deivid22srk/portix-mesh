package com.deivid22srk.portix.downloader

/** Ponte JNI para o motor Rust (`libportix_downloader.so`). */
object NativeDownloader {
    private var loaded = false
    private var loadError: String? = null

    init {
        try {
            System.loadLibrary("portix_downloader")
            loaded = true
        } catch (throwable: Throwable) {
            loadError = throwable.message
        }
    }

    val isAvailable: Boolean get() = loaded
    val error: String? get() = loadError

    /** Inicia o download e devolve um handle (>0) ou 0 em caso de falha. */
    @JvmStatic external fun startDownload(url: String, destPath: String, callback: DownloadCallback): Long

    /** Marca o download como cancelado. */
    @JvmStatic external fun cancelDownload(handle: Long)
}
