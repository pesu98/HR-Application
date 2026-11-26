package com.pesu98.leave_tracker

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val updateDir: File
        get() = File(cacheDir, "updates").apply { mkdirs() }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Used by lib/updater.dart for in-app updates.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "leave_tracker/updater")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Installed version, and where a downloaded update must be saved.
                    "info" -> result.success(
                        mapOf(
                            "version" to packageManager.getPackageInfo(packageName, 0).versionName,
                            "updateDir" to updateDir.absolutePath,
                        )
                    )

                    // Opens the Android installer for a downloaded APK.
                    "install" -> {
                        val name = call.argument<String>("fileName")
                        val apk = name?.let { File(updateDir, File(it).name) }
                        if (apk == null || !apk.isFile) {
                            result.error("missing", "Update file not found", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val uri = FileProvider.getUriForFile(this, "$packageName.updates", apk)
                            startActivity(
                                Intent(Intent.ACTION_VIEW)
                                    .setDataAndType(uri, "application/vnd.android.package-archive")
                                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("install", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
