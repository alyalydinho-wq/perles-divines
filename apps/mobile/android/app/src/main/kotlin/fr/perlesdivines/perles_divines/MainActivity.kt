package fr.perlesdivines.perles_divines

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.StatFs
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var notificationResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "perles_divines/storage")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "freeBytes" -> result.success(StatFs(filesDir.absolutePath).availableBytes)
                    "excludeBackup" -> result.success(true)
                    "ensurePlaybackNotification" -> ensurePlaybackNotification(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun ensurePlaybackNotification(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33) {
            result.success(true)
            return
        }
        val permission = Manifest.permission.POST_NOTIFICATIONS
        if (
            ContextCompat.checkSelfPermission(this, permission) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (notificationResult != null) {
            result.success(false)
            return
        }
        notificationResult = result
        requestPermissions(arrayOf(permission), notificationRequest)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != notificationRequest) return
        val granted =
            grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        val pending = notificationResult
        notificationResult = null
        pending?.success(granted)
    }

    private companion object {
        const val notificationRequest = 4101
    }
}
