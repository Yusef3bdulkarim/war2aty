package com.war2aty.app.voice

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.media.PlaybackParams
import android.os.Build

/**
 * Streams raw PCM to the speaker via [AudioTrack] (F37-T11).
 *
 * Owns audio focus for the duration of a playback session and acts as the
 * single-owner gate between itself and `flutter_tts`: requesting
 * [AudioManager.AUDIOFOCUS_GAIN] causes the system to send
 * `AUDIOFOCUS_LOSS` to whatever held focus before — including the device
 * TTS engine — so the two can never play at the same time.
 *
 * [write] is blocking in `MODE_STREAM`: it returns only when the hardware
 * has consumed enough of its buffer to accept the new chunk. The caller
 * (the channel handler in T13) must therefore call it off the UI thread.
 */
class PcmPlayer(
    private val audioManager: AudioManager,
    private val onFocusLost: () -> Unit,
) {
    companion object {
        private const val FULL_VOLUME = 1.0f

        /**
         * The level a duck drops to — quiet enough that a notification tone
         * is audible over it, loud enough that the sentence is still
         * followable, which is the whole point of ducking rather than
         * pausing.
         */
        private const val DUCKED_VOLUME = 0.3f
    }

    private var audioTrack: AudioTrack? = null
    private var sampleRate: Int = 0
    @Volatile private var hasFocus = false

    private var focusRequest: Any? = null

    /**
     * Whether playback was paused by a *transient* focus loss, and so should
     * resume by itself when focus comes back.
     *
     * A permanent [AudioManager.AUDIOFOCUS_LOSS] deliberately does not set
     * this: the read does not restart on its own into a room the user has
     * walked away from.
     */
    @Volatile private var pausedByTransientLoss = false

    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        when (change) {
            // Permanent: something else owns the speaker now. Stay paused even
            // when focus returns — see [pausedByTransientLoss].
            AudioManager.AUDIOFOCUS_LOSS -> {
                hasFocus = false
                pausedByTransientLoss = false
                audioTrack?.pause()
                onFocusLost()
            }
            // Transient and silence-requiring (a call ringing, a navigation
            // prompt): pause, and resume on GAIN. Before F37-T21's device pass
            // this fell into the same branch as the two below and nothing ever
            // called `play()` again, so the paper stopped mid-sentence for
            // good.
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                hasFocus = false
                pausedByTransientLoss = true
                audioTrack?.pause()
            }
            // Duckable: the system is asking us to get quieter, not to stop —
            // typically a notification tone. Owner's decision (2026-11-14):
            // **keep reading at a lower volume**. Pausing here was the
            // original behaviour and it meant any notification killed the
            // read; and for a user whose only output is this voice, a gap is
            // worse than a moment of competing sound.
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                audioTrack?.setVolume(DUCKED_VOLUME)
            }
            AudioManager.AUDIOFOCUS_GAIN -> {
                hasFocus = true
                // Undo a duck, whether or not we also paused: GAIN is the only
                // signal that the volume may go back up.
                audioTrack?.setVolume(FULL_VOLUME)
                if (pausedByTransientLoss) {
                    pausedByTransientLoss = false
                    audioTrack?.play()
                }
            }
        }
    }

    val isActive: Boolean get() = audioTrack != null

    /**
     * Reserves the speaker at [sampleRate] Hz, [channelCount] channels,
     * [bitsPerSample] bits. Returns `true` when the track is playing and
     * ready for [write], `false` if focus was refused or the format is
     * unsupported.
     */
    fun open(sampleRate: Int, channelCount: Int, bitsPerSample: Int): Boolean {
        if (audioTrack != null) return false

        this.sampleRate = sampleRate

        val encoding = when (bitsPerSample) {
            16 -> AudioFormat.ENCODING_PCM_16BIT
            8 -> AudioFormat.ENCODING_PCM_8BIT
            else -> return false
        }
        val channelMask = when (channelCount) {
            1 -> AudioFormat.CHANNEL_OUT_MONO
            2 -> AudioFormat.CHANNEL_OUT_STEREO
            else -> return false
        }

        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()

        if (!requestFocus(attrs)) return false
        hasFocus = true

        val minBuf = AudioTrack.getMinBufferSize(sampleRate, channelMask, encoding)
        if (minBuf <= 0) {
            abandonFocus()
            return false
        }

        val bytesPerSecond = sampleRate * channelCount * (bitsPerSample / 8)
        val bufSize = maxOf(minBuf, bytesPerSecond)

        return try {
            val track = AudioTrack.Builder()
                .setAudioAttributes(attrs)
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(sampleRate)
                        .setChannelMask(channelMask)
                        .setEncoding(encoding)
                        .build()
                )
                .setBufferSizeInBytes(bufSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()

            track.play()
            audioTrack = track
            true
        } catch (_: Exception) {
            abandonFocus()
            false
        }
    }

    /**
     * Queues [chunk] for playback. Returns the number of bytes accepted, or
     * a negative `AudioTrack.ERROR_*` constant on failure.
     */
    fun write(chunk: ByteArray): Int {
        val track = audioTrack ?: return AudioTrack.ERROR_INVALID_OPERATION
        return track.write(chunk, 0, chunk.size)
    }

    fun pause() {
        val track = audioTrack ?: return
        if (track.playState == AudioTrack.PLAYSTATE_PLAYING) {
            track.pause()
        }
    }

    fun resume() {
        val track = audioTrack ?: return
        if (hasFocus && track.playState == AudioTrack.PLAYSTATE_PAUSED) {
            track.play()
        }
    }

    fun setSpeed(multiplier: Float) {
        val track = audioTrack ?: return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            track.playbackParams = PlaybackParams().setSpeed(multiplier).setPitch(1.0f)
        } catch (_: Exception) {
        }
    }

    /** Releases the speaker and returns how many microseconds were played. */
    fun stop(): Long {
        val us = playedPositionUs()
        val track = audioTrack
        audioTrack = null
        sampleRate = 0
        hasFocus = false
        // Otherwise a focus loss during the read that was just stopped would
        // leave this set, and the *next* read's GAIN would auto-resume a
        // reading the user never started.
        pausedByTransientLoss = false
        track?.stop()
        track?.release()
        abandonFocus()
        return us
    }

    /** The playback clock: microseconds of audio the hardware has rendered. */
    fun playedPositionUs(): Long {
        val track = audioTrack ?: return 0L
        val rate = sampleRate
        if (rate == 0) return 0L
        return track.playbackHeadPosition.toLong() * 1_000_000L / rate
    }

    // -- audio focus ----------------------------------------------------

    private fun requestFocus(attrs: AudioAttributes): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = android.media.AudioFocusRequest
                .Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attrs)
                .setOnAudioFocusChangeListener(focusListener)
                .build()
            focusRequest = request
            audioManager.requestAudioFocus(request) ==
                AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                focusListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN,
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            (focusRequest as? android.media.AudioFocusRequest)?.let {
                audioManager.abandonAudioFocusRequest(it)
            }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(focusListener)
        }
        focusRequest = null
    }
}
