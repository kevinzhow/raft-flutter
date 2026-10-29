package app.raft.raft_flutter

import java.io.File
import java.nio.file.Files
import org.junit.Assert.*
import org.junit.Test

class ArtifactDocumentCleanupTest {
    private val selected = "content://qa.documents/document/selected"
    private val foreign = "content://qa.documents/document/other"

    private fun withDestination(body: (File) -> Unit) {
        val directory = Files.createTempDirectory("artifact-document-cleanup-").toFile()
        try {
            body(File(directory, "report.csv"))
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test fun failedDownloadRemovesEmptySelectedDocumentAndRejectsForeignOrReplayedReceipts() =
        withDestination { file ->
            file.createNewFile()
            val targets = ArtifactSaveTargets()
            val token = targets.selected(selected)
            val deleted = mutableListOf<String>()
            val cleanup = ArtifactDocumentCleanup(targets) { uri ->
                deleted.add(uri)
                file.delete()
            }
            assertFalse(cleanup.discard("forged", selected))
            assertFalse(cleanup.discard(token, foreign))
            assertTrue(file.exists())
            assertTrue(deleted.isEmpty())
            assertTrue(cleanup.discard(token, selected))
            assertFalse(file.exists())
            assertEquals(listOf(selected), deleted)
            assertFalse(cleanup.discard(token, selected))
            assertEquals(1, deleted.size)
        }

    @Test fun cancelDuringPartialWriteUsesTheSameExactDocumentCleanup() =
        withDestination { file ->
            file.writeBytes(ByteArray(1024) { 42 })
            val targets = ArtifactSaveTargets()
            val token = targets.selected(selected)
            var deletes = 0
            val cleanup = ArtifactDocumentCleanup(targets) { uri ->
                assertEquals(selected, uri)
                deletes++
                file.delete()
            }
            assertTrue(targets.beginWrite(token, selected))
            assertFalse(cleanup.discard(token, selected))
            assertEquals(0, deletes)
            assertEquals("cancelled", targets.cancel(token, selected))
            assertFalse(targets.finishWrite(token, selected, true))
            assertTrue(cleanup.discard(token, selected))
            assertFalse(file.exists())
            assertEquals(1, deletes)
        }

    @Test fun completeCommittedDocumentNeverReachesTheDeletionOperation() =
        withDestination { file ->
            val bytes = "name,value\n中文,42\n日本語,7\n".toByteArray()
            file.writeBytes(bytes)
            val targets = ArtifactSaveTargets()
            val token = targets.selected(selected)
            var deletes = 0
            val cleanup = ArtifactDocumentCleanup(targets) { deletes++; file.delete() }
            assertTrue(targets.beginWrite(token, selected))
            assertTrue(targets.finishWrite(token, selected, true))
            assertEquals("committed", targets.cancel(token, selected))
            assertFalse(cleanup.discard(token, selected))
            targets.acknowledge(token, selected)
            assertFalse(cleanup.discard(token, selected))
            assertEquals(0, deletes)
            assertArrayEquals(bytes, file.readBytes())
        }

    @Test fun providerFalseOrExceptionIsNeverReportedAsSuccessfulRemoval() {
        for (throws in listOf(false, true)) withDestination { file ->
            file.createNewFile()
            val targets = ArtifactSaveTargets()
            val token = targets.selected(selected)
            var deletes = 0
            val cleanup = ArtifactDocumentCleanup(targets) {
                deletes++
                if (throws) throw UnsupportedOperationException("Document provider fixture refused deletion")
                false
            }
            assertTrue(runCatching { cleanup.discard(token, selected) }.isFailure)
            assertEquals(1, deletes)
            assertTrue(file.exists())
            assertEquals(0L, file.length())
        }
    }
}
