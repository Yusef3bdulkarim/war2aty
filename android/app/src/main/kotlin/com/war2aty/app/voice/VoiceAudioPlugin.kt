package com.war2aty.app.voice

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer

/**
 * Bridges [PcmPlayer] and [AacEncoder] to Dart over two channels (F37-T13).
 *
 * A control [MethodChannel] (`com.war2aty.app/voice_audio`) carries open /
 * pause / resume / stop / beginEncode / finishEncode / abortEncode / getPosition.
 * A binary channel (`com.war2aty.app/voice_audio_pcm`) carries the raw PCM at
 * ~96 KB/s on a background task queue so that [PcmPlayer.write]'s blocking call
 * does not stall the UI thread. Every chunk is fanned to both the player and the
 * encoder — Dart sends once, Kotlin delivers twice.
 */
class VoiceAudioPlugin(engine: FlutterEngine, context: Context) {

    companion object {
        const val CONTROL_CHANNEL = "com.war2aty.app/voice_audio"
        const val PCM_CHANNEL = "com.war2aty.app/voice_audio_pcm"
    }

    private val audioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private val player = PcmPlayer(audioManager) {
        // Audio focus lost — PcmPlayer already pauses the AudioTrack.
        // The Dart side detects the stall through the position stream.
    }

    private val encoder = AacEncoder(context.cacheDir)

    private val messenger = engine.dartExecutor.binaryMessenger
    private val controlChannel = MethodChannel(messenger, CONTROL_CHANNEL)

    init {
        controlChannel.setMethodCallHandler(::handleMethod)

        val taskQueue = messenger.makeBackgroundTaskQueue()
        messenger.setMessageHandler(PCM_CHANNEL, { message, reply ->
            if (message != null) {
                val bytes = ByteArray(message.remaining())
                message.get(bytes)
                if (player.isActive) player.write(bytes)
                encoder.feed(bytes)
            }
            reply.reply(null)
        }, taskQueue)
    }

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> {
                val sr = call.argument<Int>("sampleRate")!!
                val ch = call.argument<Int>("channels")!!
                val bits = call.argument<Int>("bitsPerSample")!!
                result.success(player.open(sr, ch, bits))
            }

            "beginEncode" -> {
                val sr = call.argument<Int>("sampleRate")!!
                val ch = call.argument<Int>("channels")!!
                val bits = call.argument<Int>("bitsPerSample")!!
                result.success(encoder.begin(sr, ch, bits))
            }

            "pause" -> {
                player.pause()
                result.success(null)
            }

            "resume" -> {
                player.resume()
                result.success(null)
            }

            "stop" -> result.success(player.stop())

            "getPosition" -> result.success(player.playedPositionUs())

            "finishEncode" -> result.success(encoder.finish())

            "abortEncode" -> {
                encoder.abort()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }
}
