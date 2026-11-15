package com.war2aty.app.voice

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File

/**
 * Encodes raw PCM to AAC-LC in an .m4a container (F37-T12).
 *
 * Fed from the same stream [PcmPlayer] plays: every chunk the speaker gets
 * also lands here, so the file is written while the user listens. The encoder
 * keeps accepting data regardless of whether playback is paused — pausing the
 * muxer would break the timestamp sequence and corrupt the output.
 *
 * Spec: 24 kHz mono, 32 kbps → a 75-second read yields ≤ 0.35 MB.
 */
class AacEncoder(private val cacheDir: File) {

    companion object {
        private const val MIME_AAC = MediaFormat.MIMETYPE_AUDIO_AAC
        private const val BIT_RATE = 32_000
        private const val DEQUEUE_TIMEOUT_US = 10_000L
        private const val EOS_DRAIN_TIMEOUT_US = 100_000L
        private const val MAX_FEED_RETRIES = 100
        private const val MAX_EOS_DRAIN_ROUNDS = 500
    }

    private var codec: MediaCodec? = null
    private var muxer: MediaMuxer? = null
    private var trackIndex = -1
    private var muxerStarted = false
    private var tempFile: File? = null
    private var sampleRate = 0
    private var channelCount = 0
    private var totalBytesIn = 0L
    private var isFinished = false

    /**
     * Configures the encoder for the given PCM format. Returns true when
     * ready for [feed], false if the format is unsupported or the codec
     * could not start.
     */
    fun begin(sampleRate: Int, channelCount: Int, bitsPerSample: Int): Boolean {
        if (codec != null) return false
        if (bitsPerSample != 16) return false

        this.sampleRate = sampleRate
        this.channelCount = channelCount
        totalBytesIn = 0L
        isFinished = false

        val file = File(cacheDir, "voice_enc_${System.nanoTime()}.m4a")
        tempFile = file

        return try {
            val format = MediaFormat.createAudioFormat(MIME_AAC, sampleRate, channelCount)
            format.setInteger(
                MediaFormat.KEY_AAC_PROFILE,
                MediaCodecInfo.CodecProfileLevel.AACObjectLC,
            )
            format.setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE)

            val c = MediaCodec.createEncoderByType(MIME_AAC)
            c.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            c.start()
            codec = c

            val m = MediaMuxer(file.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            muxer = m

            true
        } catch (_: Exception) {
            releaseQuietly()
            false
        }
    }

    /**
     * Feeds raw PCM [data] to the encoder. Called from the same sequential
     * handler that feeds [PcmPlayer], never concurrently.
     */
    fun feed(data: ByteArray) {
        val c = codec ?: return
        if (isFinished) return

        val bytesPerSecond = sampleRate * channelCount * 2

        var offset = 0
        while (offset < data.size) {
            drainOutput()

            val inIdx = acquireInputBuffer(c)
            if (inIdx < 0) break

            offset += fillInputBuffer(c, inIdx, data, offset, bytesPerSecond)
        }
    }

    /**
     * Signals end of stream, drains remaining output, reads the .m4a bytes
     * and deletes the temp file. Returns null on failure.
     */
    fun finish(): ByteArray? {
        val c = codec ?: return null
        if (isFinished) return null
        isFinished = true

        val inIdx = c.dequeueInputBuffer(EOS_DRAIN_TIMEOUT_US)
        if (inIdx >= 0) {
            c.queueInputBuffer(inIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
        }

        drainOutput(untilEos = true)
        releaseQuietly()

        val file = tempFile ?: return null
        return try {
            val bytes = file.readBytes()
            file.delete()
            tempFile = null
            bytes
        } catch (_: Exception) {
            file.delete()
            tempFile = null
            null
        }
    }

    /** Discards a partial file and releases all resources. */
    fun abort() {
        isFinished = true
        releaseQuietly()
        tempFile?.delete()
        tempFile = null
    }

    private fun acquireInputBuffer(c: MediaCodec): Int {
        val idx = c.dequeueInputBuffer(DEQUEUE_TIMEOUT_US)
        if (idx >= 0) return idx

        repeat(MAX_FEED_RETRIES) {
            drainOutput()
            val retry = c.dequeueInputBuffer(DEQUEUE_TIMEOUT_US)
            if (retry >= 0) return retry
        }
        return -1
    }

    private fun fillInputBuffer(
        c: MediaCodec,
        index: Int,
        data: ByteArray,
        offset: Int,
        bytesPerSecond: Int,
    ): Int {
        val buf = c.getInputBuffer(index) ?: run {
            c.queueInputBuffer(index, 0, 0, 0, 0)
            return 0
        }
        val toWrite = minOf(data.size - offset, buf.remaining())
        buf.put(data, offset, toWrite)

        val pts = totalBytesIn * 1_000_000L / bytesPerSecond
        c.queueInputBuffer(index, 0, toWrite, pts, 0)
        totalBytesIn += toWrite
        return toWrite
    }

    private fun drainOutput(untilEos: Boolean = false) {
        val c = codec ?: return
        val m = muxer ?: return
        val info = MediaCodec.BufferInfo()
        var rounds = 0

        while (true) {
            val timeout = if (untilEos) EOS_DRAIN_TIMEOUT_US else DEQUEUE_TIMEOUT_US
            val outIdx = c.dequeueOutputBuffer(info, timeout)

            when {
                outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    if (!muxerStarted) {
                        trackIndex = m.addTrack(c.outputFormat)
                        m.start()
                        muxerStarted = true
                    }
                }

                outIdx >= 0 -> {
                    if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                        c.releaseOutputBuffer(outIdx, false)
                        continue
                    }

                    if (muxerStarted && info.size > 0) {
                        val outBuf = c.getOutputBuffer(outIdx)
                        if (outBuf != null) {
                            outBuf.position(info.offset)
                            outBuf.limit(info.offset + info.size)
                            m.writeSampleData(trackIndex, outBuf, info)
                        }
                    }

                    c.releaseOutputBuffer(outIdx, false)

                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                }

                else -> {
                    if (!untilEos) return
                    if (++rounds > MAX_EOS_DRAIN_ROUNDS) return
                }
            }
        }
    }

    private fun releaseQuietly() {
        try {
            if (muxerStarted) muxer?.stop()
            muxer?.release()
        } catch (_: Exception) { }
        muxer = null
        muxerStarted = false
        trackIndex = -1

        try {
            codec?.stop()
            codec?.release()
        } catch (_: Exception) { }
        codec = null
    }
}
