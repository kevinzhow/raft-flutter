package app.raft.raft_flutter

import java.io.File
import java.nio.file.Files
import org.junit.Assert.*
import org.junit.Test

class ClipboardImageFilesTest {
    private fun inCache(body: (ClipboardImageFiles) -> Unit) {
        val directory = Files.createTempDirectory("raft-clipboard-").toFile()
        try { body(ClipboardImageFiles(directory)) } finally { directory.deleteRecursively() }
    }

    @Test fun preparationAndFailedReplacementKeepPrecedingImage() = inCache { files ->
        val previous = files.stage(byteArrayOf(1, 2, 3))
        val next = files.stage(byteArrayOf(4, 5, 6))
        next.delete() // Host rejected clipboard ownership after preparation.
        files.sweep { it.delete() }
        assertArrayEquals(byteArrayOf(1, 2, 3), previous.readBytes())
    }

    @Test fun committedReplacementRetiresOnlyOwnedPredecessors() = inCache { files ->
        val previous = files.stage(byteArrayOf(1))
        val next = files.stage(byteArrayOf(2))
        val foreign = File(files.directory, "keep.txt").apply { writeText("unrelated") }
        val retired = mutableListOf<File>()
        files.sweep(next, replaced = true) { retired.add(it); it.delete() }
        assertEquals(listOf(previous), retired)
        assertTrue(next.exists())
        assertTrue(foreign.exists())
    }

    @Test fun expirationReclaimsAnAbandonedImageAndRetainsTheFreshOne() = inCache { files ->
        val expired = files.stage(byteArrayOf(1))
        expired.setLastModified(System.currentTimeMillis() - ClipboardImageFiles.lifetime - 1000)
        val fresh = files.stage(byteArrayOf(2))
        files.sweep { it.delete() }
        assertFalse(expired.exists())
        assertTrue(fresh.exists())
    }

    @Test fun abandonedStagesCannotGrowWithoutBoundOrDeleteTheLastClipboard() = inCache { files ->
        val previous = files.stage(byteArrayOf(1))
        val orphan = files.stage(byteArrayOf(2))
        java.io.RandomAccessFile(orphan, "rw").use { it.setLength(2L * ClipboardImageFiles.maxBytes) }
        assertTrue(runCatching { files.stage(byteArrayOf(3)) }.isFailure)
        assertArrayEquals(byteArrayOf(1), previous.readBytes())
        assertEquals(2, files.directory.listFiles()!!.size)
    }
}
