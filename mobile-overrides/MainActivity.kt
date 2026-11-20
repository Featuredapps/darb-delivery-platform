package com.darb.darb

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "DarbUpdater"
        private const val CHANNEL = "com.darb/update"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "installApk") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                try {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID_PATH", "APK path is missing", null)
                        return@setMethodCallHandler
                    }

                    val apk = File(path)
                    if (!apk.isFile || !apk.canRead() || apk.length() == 0L) {
                        result.error("APK_NOT_FOUND", "APK is missing, unreadable, or empty: $path", null)
                        return@setMethodCallHandler
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        !packageManager.canRequestPackageInstalls()
                    ) {
                        val settingsIntent = Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(settingsIntent)
                        result.success("permission_required")
                        return@setMethodCallHandler
                    }

                    val apkUri = FileProvider.getUriForFile(
                        this,
                        "$packageName.fileprovider",
                        apk
                    )
                    val installIntent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(apkUri, "application/vnd.android.package-archive")
                        clipData = ClipData.newUri(contentResolver, "Darb APK update", apkUri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(installIntent)
                    result.success("opened")
                } catch (error: Exception) {
                    Log.e(TAG, "Failed to launch Android package installer", error)
                    result.error(
                        "INSTALLER_ERROR",
                        "${error.javaClass.simpleName}: ${error.message ?: "No error message"}",
                        error.stackTraceToString()
                    )
                }
            }
    }
}
