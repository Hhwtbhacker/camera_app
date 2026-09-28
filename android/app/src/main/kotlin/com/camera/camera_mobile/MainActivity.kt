package com.camera.camera_mobile

import android.content.Intent
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Dart 侧通过 `camera_mobile/updater` 通道调用：
 *  - getVersion    : 读取当前安装包的 versionName / buildNumber
 *  - getUpdateDir  : 获取 APK 下载目录（cache/update，与 file_paths.xml 对应）
 *  - installApk    : 用 FileProvider 生成 content:// URI 并拉起系统安装器
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "camera_mobile/updater"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getVersion" -> result.success(currentVersion())
            "getUpdateDir" -> result.success(updateDir().absolutePath)
            "installApk" -> {
                val path = call.argument<String>("path")
                if (path.isNullOrEmpty()) {
                    result.error("bad_args", "缺少 path 参数", null)
                    return
                }
                try {
                    installApk(path)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("install_failed", e.message ?: "安装失败", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    /** 当前安装包的版本信息 */
    private fun currentVersion(): Map<String, Any> {
        val info = packageManager.getPackageInfo(packageName, 0)
        val buildNumber = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        return mapOf(
            "versionName" to (info.versionName ?: "0.0.0"),
            "buildNumber" to buildNumber
        )
    }

    /** 更新包下载目录：cache/update */
    private fun updateDir(): File = File(cacheDir, "update").apply { mkdirs() }

    /** 拉起系统安装器（首次会要求用户允许「安装未知应用」） */
    private fun installApk(path: String) {
        val file = File(path)
        require(file.exists()) { "安装包不存在: $path" }
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package.apk")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
