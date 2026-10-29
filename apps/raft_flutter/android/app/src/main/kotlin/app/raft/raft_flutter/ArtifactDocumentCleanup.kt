package app.raft.raft_flutter

/** Deletes only the exact, incomplete document authorized by a picker receipt. */
class ArtifactDocumentCleanup(
    private val targets: ArtifactSaveTargets,
    private val deleteDocument: (String) -> Boolean,
) {
    fun discard(token: String, uri: String): Boolean {
        if (!targets.claimDiscard(token, uri)) return false
        // A provider refusal must remain a failure, never a successful cleanup.
        check(deleteDocument(uri))
        return true
    }
}
