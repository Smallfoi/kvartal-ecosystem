package ru.mata.kvartal

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, а не FlutterActivity: плагин health спрашивает разрешения
// Health Connect через ActivityResultContract, а тот живёт только во фрагментной
// активности. С обычной FlutterActivity диалог разрешений просто не открывается.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLocationService" -> {
                    startLocationService()
                    result.success(true)
                }
                "stopLocationService" -> {
                    stopLocationService()
                    result.success(true)
                }
                "getManufacturer" -> {
                    result.success(android.os.Build.MANUFACTURER ?: "")
                }
                else -> result.notImplemented()
            }
        }
        // Шаринг в сторис Инстаграма (нативный интент, как у Стравы):
        // стикер ложится ПОВЕРХ фона, который бегун выбирает сам; карточка —
        // фоном целиком. Без Meta App ID Инстаграм интент игнорирует, поэтому
        // Dart сначала проверяет appId и честно уходит в системный шит.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTA_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareSticker" -> result.success(shareToInstagramStory(
                    call.argument("path"), call.argument("appId") ?: "", sticker = true))
                "shareBackground" -> result.success(shareToInstagramStory(
                    call.argument("path"), call.argument("appId") ?: "", sticker = false))
                else -> result.notImplemented()
            }
        }
    }

    private fun shareToInstagramStory(path: String?, appId: String, sticker: Boolean): Boolean {
        if (path == null || appId.isEmpty()) return false
        val file = java.io.File(path)
        if (!file.exists()) return false
        val uri = androidx.core.content.FileProvider.getUriForFile(
            this, "$packageName.instashare", file)
        val intent = Intent("com.instagram.share.ADD_TO_STORY").apply {
            putExtra("source_application", appId)
            putExtra("com.facebook.platform.extra.APPLICATION_ID", appId)
            if (sticker) {
                type = "image/*"
                putExtra("interactive_asset_uri", uri)
                // Градиент подложки по умолчанию — графит Квартала.
                putExtra("top_background_color", "#20252B")
                putExtra("bottom_background_color", "#0F1216")
            } else {
                setDataAndType(uri, "image/*")
            }
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        grantUriPermission("com.instagram.android", uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        return if (packageManager.resolveActivity(intent, 0) != null) {
            startActivity(intent)
            true
        } else {
            false
        }
    }

    private fun startLocationService() {
        val intent = Intent(this, KvartalLocationService::class.java).apply {
            action = KvartalLocationService.ACTION_START
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopLocationService() {
        val intent = Intent(this, KvartalLocationService::class.java).apply {
            action = KvartalLocationService.ACTION_STOP
        }
        startService(intent)
    }

    companion object {
        private const val CHANNEL = "kvartal/location_service"
        private const val INSTA_CHANNEL = "kvartal/instagram_share"
    }
}
