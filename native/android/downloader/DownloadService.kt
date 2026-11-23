package com.deivid22srk.portix.downloader

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import java.io.File
import kotlin.math.roundToInt

/**
 * Serviço em primeiro plano que baixa o APK pelo motor Rust e mostra o
 * progresso numa notificação persistente.
 */
class DownloadService : Service(), DownloadCallback {

    companion object {
        const val EXTRA_ID = "id"
        const val EXTRA_URL = "url"
        const val EXTRA_TITLE = "title"
        private const val CHANNEL_ID = "portix_downloads"
        private const val NOTIFICATION_ID = 8080

        @Volatile private var currentId: Long = 0
        @Volatile private var currentHandle: Long = 0

        fun start(context: Context, id: Long, url: String, title: String) {
            val intent = Intent(context, DownloadService::class.java).apply {
                putExtra(EXTRA_ID, id)
                putExtra(EXTRA_URL, url)
                putExtra(EXTRA_TITLE, title)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun cancel(id: Long) {
            if (id == currentId && currentHandle != 0L) {
                NativeDownloader.cancelDownload(currentHandle)
            }
        }
    }

    private var downloadId: Long = 0
    private var title: String = ""
    private var destPath: String = ""

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val id = intent?.getLongExtra(EXTRA_ID, 0L) ?: 0L
        val url = intent?.getStringExtra(EXTRA_URL) ?: ""
        val name = intent?.getStringExtra(EXTRA_TITLE) ?: "APK"
        downloadId = id
        title = name

        ensureChannel()
        startForeground(NOTIFICATION_ID, buildNotification(0, -1, ongoing = true))

        val directory = File(getExternalFilesDir(null), "apk").apply { mkdirs() }
        destPath = File(directory, "portix-$id.apk").absolutePath

        val handle = if (NativeDownloader.isAvailable) {
            NativeDownloader.startDownload(url, destPath, this)
        } else {
            0L
        }
        currentId = id
        currentHandle = handle
        if (handle == 0L) {
            onComplete(false, "motor de download indisponível")
        }
        return START_NOT_STICKY
    }

    override fun onProgress(done: Long, total: Long) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(done, total, ongoing = true))
        DownloaderBridge.emit(
            mapOf("id" to downloadId, "status" to "downloading", "done" to done, "total" to total),
        )
    }

    override fun onStats(done: Long, total: Long, speedBps: Double, etaSecs: Long) {
        DownloaderBridge.emit(
            mapOf(
                "id" to downloadId,
                "status" to "downloading",
                "done" to done,
                "total" to total,
                "speed" to speedBps,
                "eta" to etaSecs,
            ),
        )
    }

    override fun onState(state: Int) {
        val status = when (state) {
            DownloadCallback.STATE_CONNECTING -> "connecting"
            DownloadCallback.STATE_DOWNLOADING -> "downloading"
            DownloadCallback.STATE_VERIFYING -> "verifying"
            // Estados terminais chegam por onComplete (done/failed/cancelled).
            else -> return
        }
        DownloaderBridge.emit(mapOf("id" to downloadId, "status" to status))
    }

    override fun onComplete(ok: Boolean, error: String?) {
        currentHandle = 0
        DownloaderBridge.emit(
            mapOf(
                "id" to downloadId,
                "status" to if (ok) "done" else "failed",
                "path" to destPath,
                "error" to error,
            ),
        )
        Handler(Looper.getMainLooper()).post {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(
                NOTIFICATION_ID,
                buildNotification(1, 1, ongoing = false, ok = ok, error = error),
            )
            stopForeground(STOP_FOREGROUND_DETACH)
            stopSelf()
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(CHANNEL_ID, "Downloads", NotificationManager.IMPORTANCE_LOW),
                )
            }
        }
    }

    private fun buildNotification(
        done: Long,
        total: Long,
        ongoing: Boolean,
        ok: Boolean = true,
        error: String? = null,
    ): Notification {
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(title.ifEmpty { "Download" })
            .setOngoing(ongoing)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)

        if (ongoing) {
            if (total > 0) {
                val percent = ((done.toDouble() / total.toDouble()) * 100).roundToInt()
                builder.setContentText("$percent%")
                builder.setProgress(100, percent, false)
            } else {
                builder.setContentText("Baixando…")
                builder.setProgress(0, 0, true)
            }
        } else if (ok) {
            builder.setContentText("Pronto para instalar")
        } else {
            builder.setContentText(error ?: "Falhou")
        }
        return builder.build()
    }
}
