package com.lix.piraeusbanter.mobile

import android.media.MediaPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var player: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "piraeus_banter/audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "play" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank() || !File(path).exists()) {
                            result.error("missing_file", "Audio file does not exist", path)
                            return@setMethodCallHandler
                        }
                        try {
                            player?.release()
                            player = MediaPlayer().apply {
                                setDataSource(path)
                                setOnCompletionListener { it.release(); player = null }
                                prepare()
                                start()
                            }
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("play_failed", error.message, null)
                        }
                    }
                    "stop" -> {
                        player?.stop()
                        player?.release()
                        player = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        player?.release()
        player = null
        super.onDestroy()
    }
}
