package app.raft.raft_flutter

import android.content.Intent
import android.net.Uri
import android.os.ParcelFileDescriptor
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileNotFoundException

/** Existing share files retain FileProvider behavior; PNG clipboard leases are read-only. */
class ClipboardFileProvider : FileProvider() {
    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (uri.pathSegments.firstOrNull() == "clipboard-images") {
            val name = uri.pathSegments.getOrNull(1)
            if (mode != "r" || uri.pathSegments.size != 2 || name == null || !ClipboardImageFiles.owns(name)) {
                throw FileNotFoundException("Invalid clipboard image")
            }
            val file = File(File(requireNotNull(context).cacheDir, "raft-clipboard"), name)
            if (!file.isFile || ClipboardImageFiles.expired(file)) {
                context?.revokeUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                file.delete()
                throw FileNotFoundException("Clipboard image expired")
            }
        }
        return super.openFile(uri, mode)
    }
}
