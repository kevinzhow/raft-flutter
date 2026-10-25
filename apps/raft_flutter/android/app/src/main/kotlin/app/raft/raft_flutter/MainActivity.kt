package app.raft.raft_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.app.ActivityManager
import android.webkit.CookieManager
import android.webkit.WebStorage
import android.Manifest
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Bundle
import androidx.core.content.IntentCompat
import java.util.ArrayDeque
import android.os.Build
import android.content.Intent
import android.net.Uri
import java.io.File
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsAnimationCompat
import androidx.core.view.WindowInsetsCompat

class MainActivity : FlutterActivity() {
    private var shareReceiverReady = false
    private val earlyShares = ArrayDeque<Intent>()
    private var sharing: NativeSharingBridge? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        prepareSharedUris(intent)
        super.onCreate(savedInstanceState)
        // Flutter switches to NormalTheme before first paint. Give the window
        // the stored theme's canvas for that startup interval, and persist the
        // splash theme (stored appearance + enabled icon) for the next launch.
        window.setBackgroundDrawable(LaunchTheme.background(this))
        LaunchTheme.apply(this)
        consumeShare(intent)
    }

    // receive_intent forwards extras, but not ClipData. Normalize URI references
    // only: no file queries, copies, or binary data are processed here.
    private fun prepareSharedUris(intent: Intent) {
        if (intent.action !in listOf(Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE)) return
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) {
            intent.action = Intent.ACTION_MAIN
            return
        }
        try {
            intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.let { text ->
                if (text.length > 65536) { intent.action = Intent.ACTION_MAIN; return }
                intent.putExtra(Intent.EXTRA_TEXT, text.toString())
            }
            val streams = if (intent.action == Intent.ACTION_SEND_MULTIPLE)
                IntentCompat.getParcelableArrayListExtra(intent, Intent.EXTRA_STREAM, Uri::class.java) ?: emptyList()
            else listOfNotNull(IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java))
            val clips = intent.clipData?.let { clip ->
                (0 until minOf(clip.itemCount, 11)).mapNotNull { clip.getItemAt(it).uri }
            } ?: emptyList()
            intent.putStringArrayListExtra("app.raft.sharedUris", ArrayList((streams + clips).distinct().map { it.toString() }))
        } catch (_: Exception) { intent.action = Intent.ACTION_MAIN }
    }

    private fun consumeShare(intent: Intent) {
        if (intent.action in listOf(Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE)) {
            intent.action = Intent.ACTION_MAIN
            intent.removeExtra(Intent.EXTRA_STREAM)
            intent.removeExtra(Intent.EXTRA_TEXT)
            intent.removeExtra("app.raft.sharedUris")
            intent.clipData = null
        }
    }

    private fun shareReceiverAttached() {
        shareReceiverReady = true
        while (earlyShares.isNotEmpty()) dispatchNewIntent(earlyShares.removeFirst())
    }

    private fun dispatchNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeShare(intent)
    }
    private var systemFonts: NativeSystemFontsBridge? = null
    private var systemProxy: NativeProxyBridge? = null
    private var saveResult: MethodChannel.Result? = null
    private val saveRequest = 45071
    private val localNetworkRequest = 45072
    private val galleryPermissionRequest = 45073
    private var galleryPending: Pair<Map<String, String>, MethodChannel.Result>? = null
    private val localNetworkResults = mutableListOf<MethodChannel.Result>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.raft/device-memory")
            .setMethodCallHandler { call, result ->
                if (call.method == "availableStorageBytes") {
                    val path = call.argument<String>("path")
                    try {
                        if (path.isNullOrBlank()) result.error("invalid_path", "A storage path is required.", null)
                        else result.success(android.os.StatFs(path).availableBytes)
                    } catch (_: Exception) {
                        result.error("storage_unavailable", "Available storage could not be read.", null)
                    }
                } else if (call.method != "snapshot") {
                    result.notImplemented()
                } else {
                    val manager = getSystemService(ACTIVITY_SERVICE) as ActivityManager
                    val memory = ActivityManager.MemoryInfo()
                    manager.getMemoryInfo(memory)
                    result.success(mapOf("totalBytes" to memory.totalMem, "lowRam" to manager.isLowRamDevice))
                }
            }
        sharing = NativeSharingBridge(this, flutterEngine, ::shareReceiverAttached)
        systemFonts = NativeSystemFontsBridge(this, flutterEngine)
        systemProxy = NativeProxyBridge(this, flutterEngine)
        NativeBatteryBridge(this, flutterEngine)
        NativePermissionBridge(this, flutterEngine)
        LaunchTheme.register(this, flutterEngine)
        NativePdfPreviewBridge(this, flutterEngine)
        NativeVideoFrameBridge(flutterEngine)
        // Uploaded HTML previews run in an Android WebView. Its documents are
        // hostile input, so the process-wide cookie jar and web storage belong
        // to the preview while it is open: never send or keep cookies, drop
        // storage. The artifact browser is the one other WebView; it switches
        // cookies back on when it opens (`enableCookies`).
        // Mirrors the Web sandbox (opaque origin, no cookie/storage access).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.raft/html-preview-privacy")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "lockDown" -> {
                        val cookies = CookieManager.getInstance()
                        cookies.setAcceptCookie(false)
                        cookies.removeAllCookies { WebStorage.getInstance().deleteAllData(); result.success(null) }
                        cookies.flush()
                    }
                    // The in-app artifact browser needs its session cookie: it
                    // switches back on what lockDown switched off.
                    "enableCookies" -> {
                        CookieManager.getInstance().setAcceptCookie(true)
                        result.success(null)
                    }
                    "purge" -> {
                        val cookies = CookieManager.getInstance()
                        cookies.removeAllCookies { WebStorage.getInstance().deleteAllData(); result.success(null) }
                        cookies.flush()
                    }
                    else -> result.notImplemented()
                }
            }
        // System back-gesture exclusion for a rail on the window's right edge.
        // Rects are Flutter logical pixels in window coordinates; Android
        // honours at most 200 dp of exclusion per edge, so clip to that here
        // too. API 29+, a no-op below.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.raft/gesture-exclusion")
            .setMethodCallHandler { call, result ->
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "set" -> {
                        val ratio = (call.argument<Double>("ratio") ?: 1.0).toFloat()
                        val raw = call.argument<List<List<Double>>>("rects") ?: emptyList()
                        var budget = (200 * resources.displayMetrics.density).toInt()
                        val rects = ArrayList<android.graphics.Rect>()
                        for (r in raw) {
                            if (r.size != 4 || budget <= 0) continue
                            val rect = android.graphics.Rect(
                                (r[0] * ratio).toInt(), (r[1] * ratio).toInt(),
                                (r[2] * ratio).toInt(), (r[3] * ratio).toInt(),
                            )
                            if (rect.height() > budget) rect.bottom = rect.top + budget
                            budget -= rect.height()
                            rects.add(rect)
                        }
                        window.decorView.systemGestureExclusionRects = rects
                        result.success(true)
                    }
                    "clear" -> {
                        window.decorView.systemGestureExclusionRects = emptyList()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.raft/ime")
            .setMethodCallHandler { call, result ->
                if (call.method == "visible") result.success(imeVisible()) else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.raft/local-network")
            .setMethodCallHandler { call, result ->
                if (call.method != "ensure") {
                    result.notImplemented()
                } else if (Build.VERSION.SDK_INT < 37 ||
                    checkSelfPermission(Manifest.permission.ACCESS_LOCAL_NETWORK) == PackageManager.PERMISSION_GRANTED) {
                    result.success(true)
                } else if (call.argument<Boolean>("request") != true) {
                    result.success(false)
                } else {
                    localNetworkResults.add(result)
                    if (localNetworkResults.size == 1) {
                        requestPermissions(arrayOf(Manifest.permission.ACCESS_LOCAL_NETWORK), localNetworkRequest)
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.raft/attachment-files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "chooseSave" -> {
                        if (saveResult != null) {
                            result.error("busy", "A document picker is already open.", null)
                        } else {
                            saveResult = result
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = call.argument<String>("mimeType") ?: "application/octet-stream"
                                putExtra(Intent.EXTRA_TITLE, call.argument<String>("filename") ?: "attachment")
                            }
                            try { startActivityForResult(intent, saveRequest) }
                            catch (_: Exception) {
                                saveResult = null
                                result.error("unavailable", "No document picker is available.", null)
                            }
                        }
                    }
                    "writeSaved" -> {
                        val uri = call.argument<String>("uri")
                        val path = call.argument<String>("path")
                        if (uri == null || path == null ||
                            !File(path).canonicalPath.startsWith(cacheDir.canonicalPath + File.separator)) {
                            result.error("invalid", "Invalid temporary attachment file.", null)
                        } else {
                            Thread {
                                try {
                                    contentResolver.openOutputStream(Uri.parse(uri), "wt").use { output ->
                                        requireNotNull(output)
                                        File(path).inputStream().use { input -> input.copyTo(output) }
                                    }
                                    runOnUiThread { result.success(null) }
                                } catch (_: Exception) {
                                    runOnUiThread { result.error("save_failed", "The attachment could not be saved.", null) }
                                }
                            }.start()
                        }
                    }
                    "saveToGallery" -> {
                        val path = call.argument<String>("path")
                        val filename = call.argument<String>("filename")
                        val mimeType = call.argument<String>("mimeType") ?: "image/*"
                        if (path == null || filename.isNullOrEmpty() ||
                            !File(path).canonicalPath.startsWith(cacheDir.canonicalPath + File.separator)) {
                            result.error("invalid", "Invalid temporary image file.", null)
                        } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
                            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                            // Before Android 10 a public Pictures folder needs the legacy permission.
                            if (galleryPending != null) {
                                result.error("busy", "A permission request is already open.", null)
                            } else {
                                galleryPending = Pair(mapOf("path" to path, "filename" to filename, "mimeType" to mimeType), result)
                                requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), galleryPermissionRequest)
                            }
                        } else {
                            writeToGallery(path, filename, mimeType, result)
                        }
                    }
                    "openSaved" -> {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(Uri.parse(call.argument<String>("uri")),
                                    call.argument<String>("mimeType") ?: "application/octet-stream")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(intent)
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("no_viewer", "No application can open this file.", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // The IME closes with the window when the app is backgrounded. Back in the
    // foreground the system runs an IME animation that changes nothing, and at its
    // end Flutter's ImeSyncDeferringInsetsCallback re-dispatches the WindowInsets it
    // cached at the last keyboard show, so the engine reports the old
    // viewInsets.bottom although the IME is hidden (flutter#118761, device log in
    // docs/keyboard-repro.md). Re-dispatch the real insets right after every IME
    // animation ends (a callback on the decor view runs before the one Flutter
    // installed on FlutterView, hence post). Dart's KeyboardInsetGuard is the net.
    override fun onResume() {
        super.onResume()
        if (!imeAnimationObserved) {
            imeAnimationObserved = true
            ViewCompat.setWindowInsetsAnimationCallback(
                window.decorView,
                object : WindowInsetsAnimationCompat.Callback(DISPATCH_MODE_CONTINUE_ON_SUBTREE) {
                    override fun onProgress(
                        insets: WindowInsetsCompat,
                        runningAnimations: MutableList<WindowInsetsAnimationCompat>,
                    ) = insets

                    override fun onEnd(animation: WindowInsetsAnimationCompat) {
                        if (animation.typeMask and WindowInsetsCompat.Type.ime() == 0) return
                        val decor = window.decorView
                        decor.post { decor.rootWindowInsets?.let { decor.dispatchApplyWindowInsets(it) } }
                    }
                },
            )
        }
        ViewCompat.requestApplyInsets(window.decorView)
        disableNativeFocusHighlight(window.decorView)
    }

    // After any keyboard key event (hardware or an IME's Enter / Backspace) Android
    // draws its own focus ring around the focused FlutterView and keeps it through
    // later touches, like a stuck desktop focus state. Flutter paints its own focus
    // highlights (FocusManager.highlightMode follows touch vs key input), so the
    // platform ring is never wanted.
    private fun disableNativeFocusHighlight(view: android.view.View) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) view.defaultFocusHighlightEnabled = false
        if (view is android.view.ViewGroup) {
            for (i in 0 until view.childCount) disableNativeFocusHighlight(view.getChildAt(i))
        }
    }

    private var imeAnimationObserved = false

    // null when the insets are not attached yet: Dart then trusts the engine.
    private fun imeVisible(): Boolean? =
        ViewCompat.getRootWindowInsets(window.decorView)?.isVisible(WindowInsetsCompat.Type.ime())

    override fun onNewIntent(intent: Intent) {
        prepareSharedUris(intent)
        if (!shareReceiverReady && intent.action in listOf(Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE)) {
            earlyShares.addLast(intent)
            return
        }
        dispatchNewIntent(intent)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        systemFonts?.configurationChanged()
    }

    /** Adds an image to the public gallery (MediaStore); off the UI thread. */
    private fun writeToGallery(path: String, filename: String, mimeType: String, result: MethodChannel.Result) {
        Thread {
            try {
                val source = File(path)
                val uri: String
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val values = android.content.ContentValues().apply {
                        put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, filename)
                        put(android.provider.MediaStore.MediaColumns.MIME_TYPE, mimeType)
                        put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/Raft")
                        put(android.provider.MediaStore.MediaColumns.IS_PENDING, 1)
                    }
                    val target = requireNotNull(contentResolver.insert(
                        android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values))
                    try {
                        contentResolver.openOutputStream(target, "wt").use { output ->
                            requireNotNull(output)
                            source.inputStream().use { input -> input.copyTo(output) }
                        }
                        val done = android.content.ContentValues().apply {
                            put(android.provider.MediaStore.MediaColumns.IS_PENDING, 0)
                        }
                        contentResolver.update(target, done, null, null)
                    } catch (e: Exception) {
                        contentResolver.delete(target, null, null)
                        throw e
                    }
                    uri = target.toString()
                } else {
                    @Suppress("DEPRECATION")
                    val folder = File(android.os.Environment.getExternalStoragePublicDirectory(
                        android.os.Environment.DIRECTORY_PICTURES), "Raft")
                    check(folder.isDirectory || folder.mkdirs())
                    var destination = File(folder, filename)
                    var n = 1
                    while (destination.exists()) {
                        val dot = filename.lastIndexOf('.')
                        destination = File(folder, if (dot > 0) filename.substring(0, dot) + " ($n)" + filename.substring(dot) else "$filename ($n)")
                        n++
                    }
                    source.copyTo(destination)
                    android.media.MediaScannerConnection.scanFile(this, arrayOf(destination.path), arrayOf(mimeType), null)
                    uri = Uri.fromFile(destination).toString()
                }
                runOnUiThread { result.success(uri) }
            } catch (_: Exception) {
                runOnUiThread { result.error("save_failed", "The image could not be saved.", null) }
            }
        }.start()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == galleryPermissionRequest) {
            val pending = galleryPending
            galleryPending = null
            if (pending != null) {
                val (args, result) = pending
                if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
                    writeToGallery(args.getValue("path"), args.getValue("filename"), args.getValue("mimeType"), result)
                } else {
                    result.error("permission", "Photo library access was declined.", null)
                }
            }
            return
        }
        if (requestCode == localNetworkRequest) {
            val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            val pending = localNetworkResults.toList()
            localNetworkResults.clear()
            pending.forEach { it.success(granted) }
        }
    }

    override fun onDestroy() {
        earlyShares.clear()
        sharing?.dispose()
        systemFonts?.dispose()
        systemProxy?.dispose()
        localNetworkResults.forEach { it.success(false) }
        localNetworkResults.clear()
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (sharing?.onActivityResult(requestCode) == true) return
        if (requestCode == saveRequest) {
            val pending = saveResult
            saveResult = null
            pending?.success(if (resultCode == Activity.RESULT_OK) data?.data?.toString() else null)
        } else { super.onActivityResult(requestCode, resultCode, data) }
    }
}
