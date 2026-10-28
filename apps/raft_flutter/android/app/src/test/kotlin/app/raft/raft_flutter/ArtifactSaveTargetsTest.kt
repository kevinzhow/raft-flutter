package app.raft.raft_flutter

import org.junit.Assert.*
import org.junit.Test

class ArtifactSaveTargetsTest {
    private val first = "content://qa.documents/document/first"
    private val second = "content://qa.documents/document/second"

    @Test fun onlyPickerReceiptCanOwnExactTarget() {
        val receipts = ArtifactSaveTargets()
        assertFalse(receipts.claimDiscard("forged", first))
        val one = receipts.selected(first)
        val two = receipts.selected(second)
        assertNotEquals(one, two)
        assertFalse(receipts.claimDiscard(one, second))
        assertFalse(receipts.beginWrite("forged", first))
        assertTrue(receipts.claimDiscard(one, first))
        assertFalse(receipts.claimDiscard(one, first))
        assertTrue(receipts.owns(second))
    }

    @Test fun cancelDuringWritePreventsCommitAndAuthorizesOnlyExactCleanup() {
        val receipts = ArtifactSaveTargets()
        val token = receipts.selected(first)
        assertTrue(receipts.beginWrite(token, first))
        assertFalse(receipts.beginWrite(token, first))
        assertFalse(receipts.claimDiscard(token, first))
        assertEquals("invalid", receipts.cancel(token, second))
        assertEquals("cancelled", receipts.cancel(token, first))
        assertTrue(receipts.isCancelled(token, first))
        assertFalse(receipts.finishWrite(token, first, true))
        assertTrue(receipts.claimDiscard(token, first))
        assertFalse(receipts.claimDiscard(token, first))
    }

    @Test fun committedFileRejectsLateCancelDeletionAndReceiptReplay() {
        val receipts = ArtifactSaveTargets()
        val token = receipts.selected(first)
        assertTrue(receipts.beginWrite(token, first))
        assertTrue(receipts.finishWrite(token, first, true))
        assertFalse(receipts.owns(first))
        assertEquals("committed", receipts.cancel(token, first))
        assertFalse(receipts.claimDiscard(token, first))
        assertFalse(receipts.beginWrite(token, first))
        receipts.acknowledge(token, second)
        assertEquals("committed", receipts.cancel(token, first))
        receipts.acknowledge(token, first)
        assertEquals("invalid", receipts.cancel(token, first))
    }

    @Test fun failedWriteCanBeDiscardedButDuplicateUrisAndUnsafeTargetsAreRejected() {
        val receipts = ArtifactSaveTargets()
        val token = receipts.selected(first)
        assertTrue(receipts.beginWrite(token, first))
        assertFalse(receipts.finishWrite(token, second, true))
        assertFalse(receipts.finishWrite(token, first, false))
        assertTrue(runCatching { receipts.selected(first) }.isFailure)
        assertTrue(receipts.claimDiscard(token, first))
        assertTrue(runCatching { receipts.selected("file:///private/file") }.isFailure)
    }
}
