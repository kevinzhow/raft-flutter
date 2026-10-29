package app.raft.raft_flutter

import android.graphics.Bitmap
import android.media.MediaDataSource
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * The first picture and the real shape of a video from its signed URL, without
 * downloading the file (channel `app.raft/video-frame`, contract in
 * lib/platform/video_frame_probe.dart).
 *
 * `MediaMetadataRetriever.setDataSource(url, headers)` hands the URL to the media
 * server process, which reads it with no byte cap, no timeout we control and no
 * way to stop it, so the retriever reads through [RangeDataSource] instead: HTTP
 * `Range` requests in read-ahead blocks, a hard cap on the bytes received, and
 * connections that close at once when the probe is cancelled or times out.
 *
 * The URL is a signed capability: nothing here logs it, and error messages sent
 * to Dart are fixed texts.
 */
class NativeVideoFrameBridge(engine: FlutterEngine) {
    private val main = Handler(Looper.getMainLooper())
    private val jobs = ConcurrentHashMap<String, Job>()
    // At most two probes read at once (Dart limits itself to two as well); more wait in a bounded queue.
    private val workers = ThreadPoolExecutor(
        2, 2, 30, TimeUnit.SECONDS, LinkedBlockingQueue(64),
        { task -> Thread(task, "raft-video-frame").apply { isDaemon = true } },
    ).apply { allowCoreThreadTimeOut(true) }
    private val timers = Executors.newSingleThreadScheduledExecutor { task ->
        Thread(task, "raft-video-frame-timer").apply { isDaemon = true }
    }

    init {
        MethodChannel(engine.dartExecutor.binaryMessenger, "app.raft/video-frame")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "probe" -> probe(call, result)
                    "cancel" -> {
                        val id = call.argument<String>("id")
                        if (id != null) jobs[id]?.finish(Outcome.Cancelled)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private sealed class Outcome {
        class Done(val data: Map<String, Any?>) : Outcome()
        object Cancelled : Outcome()
        object Expired : Outcome()
        class Failed(val message: String) : Outcome()
    }

    private inner class Job(val id: String, private val result: MethodChannel.Result) {
        private val done = AtomicBoolean(false)
        @Volatile var source: RangeDataSource? = null
        @Volatile var timer: ScheduledFuture<*>? = null
        /** The reason the source gave up with (expired, byte budget...), read when the retriever throws. */
        @Volatile var reason: Outcome? = null
        val finished get() = done.get()

        /** Answers Dart once; the first outcome wins. Also stops the reads of this probe. */
        fun finish(outcome: Outcome) {
            if (!done.compareAndSet(false, true)) return
            jobs.remove(id, this)
            timer?.cancel(false)
            source?.abort()
            main.post {
                when (outcome) {
                    is Outcome.Done -> result.success(outcome.data)
                    Outcome.Cancelled -> result.error("cancelled", "The probe was cancelled.", null)
                    Outcome.Expired -> result.error("expired", "The video address is no longer valid.", null)
                    is Outcome.Failed -> result.error("failed", outcome.message, null)
                }
            }
        }
    }

    private fun probe(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        val url = call.argument<String>("url")
        if (id == null || url == null) {
            result.error("failed", "Missing arguments.", null); return
        }
        @Suppress("UNCHECKED_CAST")
        val headers = (call.argument<Map<String, Any?>>("headers") ?: emptyMap())
            .mapNotNull { (k, v) -> (v as? String)?.let { k to it } }.toMap()
        val maxEdge = (call.argument<Number>("maxEdge")?.toInt() ?: 640).coerceIn(16, 4096)
        val timeoutMs = (call.argument<Number>("timeoutMs")?.toLong() ?: 20_000L).coerceIn(1_000L, 120_000L)
        val maxBytes = (call.argument<Number>("maxBytes")?.toLong() ?: (16L shl 20)).coerceIn(64L shl 10, 256L shl 20)
        val parsed = try {
            URL(url).takeIf { it.protocol == "http" || it.protocol == "https" }
        } catch (_: Exception) { null }
        if (parsed == null) {
            result.error("failed", "Only http and https video addresses are read.", null); return
        }
        val job = Job(id, result)
        jobs.put(id, job)?.finish(Outcome.Cancelled)
        try {
            workers.execute { run(job, parsed, headers, maxEdge, timeoutMs, maxBytes) }
        } catch (_: RejectedExecutionException) {
            job.finish(Outcome.Failed("Too many video probes."))
        }
    }

    private fun run(job: Job, url: URL, headers: Map<String, String>, maxEdge: Int, timeoutMs: Long, maxBytes: Long) {
        if (job.finished) return
        job.timer = timers.schedule({ job.finish(Outcome.Failed("The probe timed out.")) }, timeoutMs, TimeUnit.MILLISECONDS)
        val retriever = MediaMetadataRetriever()
        try {
            val source = RangeDataSource(url, headers, maxBytes, job)
            job.source = source
            if (job.finished) source.abort()
            retriever.setDataSource(source)
            if (job.finished) return
            job.finish(Outcome.Done(extract(retriever, maxEdge, job)))
        } catch (error: Throwable) {
            // The source records why it stopped (expired, byte budget); the retriever's own exception only says "failed".
            val reason = job.reason
            if (reason == null) Log.w(TAG, "probe failed: ${error.javaClass.simpleName}")
            job.finish(reason ?: Outcome.Failed("The video could not be read."))
        } finally {
            try { retriever.release() } catch (_: Throwable) {}
            job.source?.abort()
            job.timer?.cancel(false)
        }
    }

    private fun extract(retriever: MediaMetadataRetriever, maxEdge: Int, job: Job): Map<String, Any?> {
        fun meta(key: Int) = retriever.extractMetadata(key)
        if (meta(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO) != "yes") throw IOException("no video track")
        val storedW = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
        val storedH = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
        val rotation = ((meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0) % 360 + 360) % 360
        val durationMs = meta(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()?.coerceIn(0, Int.MAX_VALUE.toLong())?.toInt() ?: 0
        if (storedW <= 0 || storedH <= 0) throw IOException("no size")
        val swap = rotation == 90 || rotation == 270
        val width = if (swap) storedH else storedW
        val height = if (swap) storedW else storedH

        var bitmap = frame(retriever, 0L, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, width, height, maxEdge)
        if (bitmap == null || isBlack(bitmap)) {
            // Frame 0 is missing or black (a fade-in): the nearest picture after 100 ms, decoded exactly.
            val later = if (job.finished) null else frame(retriever, 100_000L, MediaMetadataRetriever.OPTION_CLOSEST, width, height, maxEdge)
            if (later != null) { bitmap?.recycle(); bitmap = later }
        }
        val jpeg = bitmap?.let {
            try {
                ByteArrayOutputStream().also { out -> if (!it.compress(Bitmap.CompressFormat.JPEG, 80, out)) throw IOException("jpeg") }.toByteArray()
            } finally { it.recycle() }
        }
        return mapOf("jpeg" to jpeg, "width" to width, "height" to height, "rotation" to rotation, "durationMs" to durationMs)
    }

    /** One upright picture whose longest edge is at most [maxEdge], or null when the platform has none. */
    private fun frame(r: MediaMetadataRetriever, timeUs: Long, option: Int, displayW: Int, displayH: Int, maxEdge: Int): Bitmap? {
        val scale = minOf(1.0, maxEdge.toDouble() / max(displayW, displayH))
        val target = max(1, (displayW * scale).roundToInt()) to max(1, (displayH * scale).roundToInt())
        val raw = try {
            if (Build.VERSION.SDK_INT >= 27 && scale < 1.0) r.getScaledFrameAtTime(timeUs, option, target.first, target.second)
            else r.getFrameAtTime(timeUs, option)
        } catch (_: RuntimeException) { null } ?: return null
        if (max(raw.width, raw.height) <= maxEdge) return raw
        val s = maxEdge.toDouble() / max(raw.width, raw.height)
        val scaled = Bitmap.createScaledBitmap(raw, max(1, (raw.width * s).roundToInt()), max(1, (raw.height * s).roundToInt()), true)
        if (scaled !== raw) raw.recycle()
        return scaled
    }

    /** A sparse grid of samples that are all near black. */
    private fun isBlack(bitmap: Bitmap): Boolean {
        val steps = 12
        for (yi in 0 until steps) for (xi in 0 until steps) {
            val p = bitmap.getPixel((bitmap.width - 1) * xi / (steps - 1), (bitmap.height - 1) * yi / (steps - 1))
            val luma = (((p shr 16) and 0xff) * 3 + ((p shr 8) and 0xff) * 6 + (p and 0xff)) / 10
            if (luma > 12) return false
        }
        return true
    }

    /**
     * A seekable view of the video over HTTP range requests. The retriever asks for small pieces at arbitrary
     * positions (top-level boxes, the index, the first sample); each miss fetches one [BLOCK] aligned block, and the
     * last few blocks stay in memory. The total of bytes received is capped at [maxBytes].
     */
    private inner class RangeDataSource(
        private var url: URL,
        private val headers: Map<String, String>,
        private val maxBytes: Long,
        private val job: Job,
    ) : MediaDataSource() {
        private val aborted = AtomicBoolean(false)
        @Volatile private var connection: HttpURLConnection? = null
        private var size = -1L
        private var ranges = true
        private var received = 0L
        private val cache = object : LinkedHashMap<Long, ByteArray>(8, 0.75f, true) {
            override fun removeEldestEntry(eldest: MutableMap.MutableEntry<Long, ByteArray>?) = this.size > BLOCKS
        }

        fun abort() {
            if (!aborted.compareAndSet(false, true)) return
            try { connection?.disconnect() } catch (_: Throwable) {}
        }

        private fun give(outcome: Outcome): Nothing {
            if (job.reason == null) job.reason = outcome
            throw IOException("stopped")
        }

        @Synchronized override fun getSize(): Long {
            if (size < 0) block(0)
            return size
        }

        @Synchronized override fun readAt(position: Long, buffer: ByteArray, offset: Int, length: Int): Int {
            if (length == 0) return 0
            if (position < 0) return -1
            if (size < 0) block(0)
            var copied = 0
            var at = position
            while (copied < length) {
                if (size in 0..at) break
                val index = at / BLOCK
                val data = block(index)
                val inBlock = (at - index * BLOCK).toInt()
                if (inBlock >= data.size) break
                val n = minOf(length - copied, data.size - inBlock)
                System.arraycopy(data, inBlock, buffer, offset + copied, n)
                copied += n; at += n
            }
            return if (copied == 0) -1 else copied
        }

        private fun block(index: Long): ByteArray {
            cache[index]?.let { return it }
            if (aborted.get()) give(job.reason ?: Outcome.Cancelled)
            val start = index * BLOCK
            if (!ranges && start > 0) give(Outcome.Failed("The host does not serve byte ranges."))
            val data = fetch(start)
            cache[index] = data
            return data
        }

        private fun fetch(start: Long): ByteArray {
            val end = if (size >= 0) minOf(start + BLOCK - 1, size - 1) else start + BLOCK - 1
            val wanted = (end - start + 1).toInt()
            if (received >= maxBytes) give(Outcome.Failed("The byte budget was spent."))
            var request: HttpURLConnection? = null
            // A body read to its end leaves the connection reusable for the next block; anything else closes it.
            var reusable = false
            try {
                request = open(start, end)
                val code = request.responseCode
                if (code == 401 || code == 403 || code == 410) give(Outcome.Expired)
                if (code == 416 && size >= 0) return ByteArray(0)
                if (code != 200 && code != 206) give(Outcome.Failed("The host answered $code."))
                if (code == 206) {
                    // Content-Range: bytes first-last/total
                    val total = request.getHeaderField("Content-Range")?.substringAfter('/', "")?.trim()?.toLongOrNull()
                    if (total != null) size = total
                } else {
                    // The host ignored the range: only the first block can be taken from the start of the stream.
                    ranges = false
                    if (start > 0) give(Outcome.Failed("The host does not serve byte ranges."))
                    request.contentLengthLong.takeIf { it >= 0 }?.let { size = it }
                }
                val limit = if (code == 200) wanted else minOf(wanted.toLong(), request.contentLengthLong.takeIf { it >= 0 } ?: wanted.toLong()).toInt()
                val out = ByteArray(limit)
                var filled = 0
                request.inputStream.use { stream ->
                    while (filled < limit) {
                        if (aborted.get()) give(job.reason ?: Outcome.Cancelled)
                        val n = stream.read(out, filled, limit - filled)
                        if (n < 0) break
                        filled += n
                        received += n
                        if (received > maxBytes) give(Outcome.Failed("The byte budget was spent."))
                    }
                }
                reusable = code == 206 && filled == limit
                return if (filled == out.size) out else out.copyOf(filled)
            } catch (error: IOException) {
                if (aborted.get()) give(job.reason ?: if (job.finished) Outcome.Cancelled else Outcome.Failed("The probe stopped."))
                // A network error text can carry the address; the system logs what readAt throws.
                throw IOException("read failed")
            } finally {
                if (!reusable) try { request?.disconnect() } catch (_: Throwable) {}
                connection = null
            }
        }

        /** Opens one range request, following up to three redirects by hand (no custom headers cross to another host). */
        private fun open(start: Long, end: Long): HttpURLConnection {
            var target = url
            var carry = true
            repeat(4) {
                val c = target.openConnection() as HttpURLConnection
                connection = c
                if (aborted.get()) { c.disconnect(); give(job.reason ?: Outcome.Cancelled) }
                c.instanceFollowRedirects = false
                c.connectTimeout = 10_000
                c.readTimeout = 15_000
                c.useCaches = false
                if (carry) headers.forEach { (k, v) -> c.setRequestProperty(k, v) }
                c.setRequestProperty("Accept-Encoding", "identity")
                c.setRequestProperty("Range", "bytes=$start-$end")
                val code = c.responseCode
                if (code in 301..308 && code != 304 && code != 305 && code != 306) {
                    val next = c.getHeaderField("Location")?.let { URL(target, it) }
                    c.disconnect()
                    if (next == null || (next.protocol != "http" && next.protocol != "https")) give(Outcome.Failed("A bad redirect."))
                    if (next.host != target.host || next.port != target.port) carry = false
                    target = next
                    return@repeat
                }
                // Later blocks go straight to the final address.
                url = target
                return c
            }
            give(Outcome.Failed("Too many redirects."))
        }

        override fun close() = abort()
    }

    private companion object {
        const val TAG = "RaftVideoFrame"
        const val BLOCK = 256L * 1024
        const val BLOCKS = 4
    }
}
