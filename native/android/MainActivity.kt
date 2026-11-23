package com.deivid22srk.portix

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.content.FileProvider
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.deivid22srk.portix.apk.PortixApkTools
import com.deivid22srk.portix.device.PortixDeviceInfo
import com.deivid22srk.portix.downloader.DownloadService
import com.deivid22srk.portix.downloader.DownloaderBridge
import com.deivid22srk.portix.downloader.NativeDownloader
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Atividade principal. Além do Flutter padrão, expõe os canais do sistema de
 * download (iniciar/cancelar/instalar) e o fluxo de eventos de progresso.
 */
class MainActivity : FlutterActivity() {
    private val methodsChannelName = "portix/downloader"
    private val eventsChannelName = "portix/downloader/events"
    private val deviceChannelName = "portix/device"
    private val apkChannelName = "portix/apk"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Edge-to-edge: deixa o Flutter receber os insets reais da barra de
        // navegação (gestos ou 3 botões) em todos os aparelhos.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = android.graphics.Color.TRANSPARENT
        window.navigationBarColor = android.graphics.Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
        val controller = WindowInsetsControllerCompat(window, window.decorView)
        controller.isAppearanceLightStatusBars = false
        controller.isAppearanceLightNavigationBars = false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(NativeDownloader.isAvailable)
                    "requestNotifications" -> {
                        requestNotifications()
                        result.success(true)
                    }
                    "start" -> {
                        val id = call.argument<Number>("id")?.toLong() ?: 0L
                        val url = call.argument<String>("url").orEmpty()
                        val title = call.argument<String>("title") ?: "APK"
                        if (url.isEmpty()) {
                            result.success(false)
                        } else {
                            DownloadService.start(applicationContext, id, url, title)
                            result.success(true)
                        }
                    }
                    "cancel" -> {
                        val id = call.argument<Number>("id")?.toLong() ?: 0L
                        DownloadService.cancel(id)
                        result.success(true)
                    }
                    "install" -> result.success(installApk(call.argument<String>("path")))
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventsChannelName)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        DownloaderBridge.events = events
                    }

                    override fun onCancel(arguments: Any?) {
                        DownloaderBridge.events = null
                    }
                },
            )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "info" -> result.success(PortixDeviceInfo.collect(applicationContext))
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, apkChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "inspect" -> {
                        val path = call.argument<String>("path")
                        result.success(path?.let { PortixApkTools.inspect(applicationContext, it) })
                    }
                    "installed" -> {
                        val pkg = call.argument<String>("packageName")
                        result.success(pkg?.let { PortixApkTools.installed(applicationContext, it) })
                    }
                    "launch" -> {
                        val pkg = call.argument<String>("packageName")
                        result.success(pkg != null && PortixApkTools.launch(applicationContext, pkg))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestNotifications() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4711)
        }
    }

    private fun installApk(path: String?): Boolean {
        if (path.isNullOrEmpty()) {
            return false
        }
        return try {
            val file = File(path)
            if (!file.exists()) {
                return false
            }
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (throwable: Throwable) {
            false
        }
    }
}
