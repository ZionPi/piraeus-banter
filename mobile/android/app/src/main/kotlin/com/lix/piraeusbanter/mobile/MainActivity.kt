package com.lix.piraeusbanter.mobile

import android.media.MediaPlayer
import android.media.MediaMetadataRetriever
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.audio.SpeedProvider
import androidx.media3.common.util.UnstableApi
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

@OptIn(UnstableApi::class)
class MainActivity : FlutterActivity() {
    private var player: MediaPlayer? = null
    private var transformer: Transformer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "piraeus_banter/audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "play" -> {
                        val path = call.argument<String>("path")
                        val speed = (call.argument<Double>("speed") ?: 1.0).toFloat().coerceIn(0.5f, 4.0f)
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
                                playbackParams = playbackParams.setSpeed(speed)
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
                    "pause" -> {
                        player?.pause()
                        result.success(null)
                    }
                    "resume" -> {
                        player?.start()
                        result.success(null)
                    }
                    "merge" -> {
                        val paths = call.argument<List<String>>("paths").orEmpty()
                        val outputPath = call.argument<String>("outputPath")
                        val speed = (call.argument<Double>("speed") ?: 1.0)
                            .toFloat()
                            .coerceIn(0.5f, 4.0f)
                        if (transformer != null) {
                            result.error("merge_busy", "An audio export is already running", null)
                            return@setMethodCallHandler
                        }
                        if (paths.isEmpty() || paths.any { !File(it).exists() }) {
                            result.error("missing_file", "One or more audio files do not exist", null)
                            return@setMethodCallHandler
                        }
                        if (outputPath.isNullOrBlank()) {
                            result.error("missing_output", "Output path is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val speedProvider = object : SpeedProvider {
                                override fun getSpeed(timeUs: Long): Float = speed

                                override fun getNextSpeedChangeTimeUs(timeUs: Long): Long = C.TIME_UNSET
                            }
                            val items = paths.map { path ->
                                EditedMediaItem.Builder(MediaItem.fromUri(File(path).toURI().toString()))
                                    .setSpeed(speedProvider)
                                    .build()
                            }
                            val sequence = EditedMediaItemSequence.Builder(setOf(C.TRACK_TYPE_AUDIO))
                                .addItems(items)
                                .build()
                            val composition = Composition.Builder(sequence).build()
                            File(outputPath).delete()
                            transformer = Transformer.Builder(this)
                                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                                .addListener(object : Transformer.Listener {
                                    override fun onCompleted(
                                        composition: Composition,
                                        exportResult: ExportResult,
                                    ) {
                                        transformer = null
                                        result.success(outputPath)
                                    }

                                    override fun onError(
                                        composition: Composition,
                                        exportResult: ExportResult,
                                        exportException: ExportException,
                                    ) {
                                        transformer = null
                                        File(outputPath).delete()
                                        result.error("merge_failed", exportException.message, null)
                                    }
                                })
                                .build()
                            transformer?.start(composition, outputPath)
                        } catch (error: Exception) {
                            transformer = null
                            File(outputPath).delete()
                            result.error("merge_failed", error.message, null)
                        }
                    }
                    "duration" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank() || !File(path).exists()) {
                            result.error("missing_file", "Audio file does not exist", path)
                            return@setMethodCallHandler
                        }
                        try {
                            val retriever = MediaMetadataRetriever()
                            retriever.setDataSource(path)
                            val duration = retriever
                                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                                ?.toIntOrNull() ?: 0
                            retriever.release()
                            result.success(duration)
                        } catch (error: Exception) {
                            result.error("duration_failed", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        transformer?.cancel()
        transformer = null
        player?.release()
        player = null
        super.onDestroy()
    }
}
