package com.deivid22srk.portix.apk

import android.content.Context
import android.content.Intent
import android.os.Build

/** Inspeção de APK e apps instalados (nome do pacote, versão e abrir app). */
object PortixApkTools {
    fun inspect(context: Context, path: String): Map<String, Any?>? {
        val info = context.packageManager.getPackageArchiveInfo(path, 0) ?: return null
        return mapOf(
            "packageName" to info.packageName,
            "versionName" to info.versionName,
            "versionCode" to versionCode(info),
        )
    }

    fun installed(context: Context, packageName: String): Map<String, Any?>? {
        return try {
            val info = context.packageManager.getPackageInfo(packageName, 0)
            mapOf(
                "packageName" to info.packageName,
                "versionName" to info.versionName,
                "versionCode" to versionCode(info),
            )
        } catch (error: Exception) {
            null
        }
    }

    fun launch(context: Context, packageName: String): Boolean {
        val intent: Intent = context.packageManager.getLaunchIntentForPackage(packageName)
            ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            context.startActivity(intent)
            true
        } catch (error: Exception) {
            false
        }
    }

    private fun versionCode(info: android.content.pm.PackageInfo): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
    }
}
