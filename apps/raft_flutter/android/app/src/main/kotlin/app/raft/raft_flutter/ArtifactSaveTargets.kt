package app.raft.raft_flutter

import java.net.URI
import java.util.UUID

/** Per-Activity receipts for newly selected, incomplete Artifact documents. */
class ArtifactSaveTargets {
    private data class Target(
        val uri: String,
        var writing: Boolean = false,
        var cancelled: Boolean = false,
        var committed: Boolean = false,
    )
    private val targets = mutableMapOf<String, Target>()

    @Synchronized
    fun selected(uri: String): String {
        val parsed = URI(uri)
        require(parsed.scheme == "content" && !parsed.rawAuthority.isNullOrBlank())
        require(targets.values.none { it.uri == uri })
        val token = UUID.randomUUID().toString()
        targets[token] = Target(uri)
        return token
    }

    @Synchronized
    fun owns(uri: String): Boolean = targets.values.any { it.uri == uri && !it.committed }

    @Synchronized
    fun beginWrite(token: String, uri: String): Boolean {
        val target = targets[token] ?: return false
        if (target.uri != uri || target.writing || target.cancelled || target.committed) return false
        target.writing = true
        return true
    }

    @Synchronized
    fun finishWrite(token: String, uri: String, success: Boolean): Boolean {
        val target = targets[token] ?: return false
        if (target.uri != uri || !target.writing) return false
        target.writing = false
        target.committed = success && !target.cancelled
        return target.committed
    }

    @Synchronized
    fun cancel(token: String, uri: String): String {
        val target = targets[token] ?: return "invalid"
        if (target.uri != uri) return "invalid"
        if (target.committed) return "committed"
        target.cancelled = true
        return "cancelled"
    }

    @Synchronized
    fun isCancelled(token: String, uri: String): Boolean =
        targets[token]?.let { it.uri == uri && it.cancelled && !it.committed } == true

    @Synchronized
    fun acknowledge(token: String, uri: String) {
        if (targets[token]?.let { it.uri == uri && it.committed } == true) targets.remove(token)
    }

    @Synchronized
    fun claimDiscard(token: String, uri: String): Boolean {
        val target = targets[token] ?: return false
        if (target.uri != uri || target.writing || target.committed) return false
        targets.remove(token)
        return true
    }
}
