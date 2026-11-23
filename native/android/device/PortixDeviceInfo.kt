package com.deivid22srk.portix.device

import android.app.ActivityManager
import android.content.Context
import android.os.Build

/** Coleta dados do aparelho para o feedback de compatibilidade. */
object PortixDeviceInfo {
    fun collect(context: Context): Map<String, Any?> {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memory = ActivityManager.MemoryInfo()
        manager.getMemoryInfo(memory)
        val ramGb = (memory.totalMem / (1024L * 1024L * 1024L)).toInt()

        val glEsVersion = manager.deviceConfigurationInfo.glEsVersion
        val soc = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOfNotNull(Build.SOC_MANUFACTURER, Build.SOC_MODEL)
                .joinToString(" ")
                .trim()
        } else {
            Build.HARDWARE
        }

        return mapOf(
            "brand" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "hardware" to Build.HARDWARE,
            "soc" to soc.ifBlank { Build.HARDWARE },
            "cores" to Runtime.getRuntime().availableProcessors(),
            "ramGb" to ramGb,
            "gpu" to "OpenGL ES $glEsVersion",
            "sdk" to Build.VERSION.SDK_INT,
        )
    }
}
