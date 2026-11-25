package com.coffeehauslabs.nightingale_tv

import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@UnstableApi
class HdrRuleTest {
    private val pq = C.COLOR_TRANSFER_ST2084
    private val hlg = C.COLOR_TRANSFER_HLG
    private val sdr = C.COLOR_TRANSFER_SDR
    private val dolbyVision = 1
    private val hdr10 = 2
    private val hlgType = 3
    private val hdr10Plus = 4

    @Test
    fun whatIsHdr() {
        assertTrue(HdrRule.isHdr(pq))
        assertTrue(HdrRule.isHdr(hlg))
        assertFalse(HdrRule.isHdr(sdr))
        assertFalse(HdrRule.isHdr(null))
    }

    @Test
    fun whatADisplayShows() {
        assertTrue(HdrRule.shows(pq, listOf(hdr10)))
        assertTrue(HdrRule.shows(pq, listOf(hdr10Plus)))
        assertFalse(HdrRule.shows(pq, listOf(hlgType)))
        assertFalse(HdrRule.shows(pq, listOf(dolbyVision)))
        assertFalse(HdrRule.shows(pq, emptyList()))
        assertTrue(HdrRule.shows(hlg, listOf(hdr10, hlgType)))
        assertFalse(HdrRule.shows(hlg, listOf(hdr10)))
        assertFalse(HdrRule.shows(sdr, listOf(hdr10, hlgType)))
    }

    @Test
    fun sdrIsAskedForOnlyWhereItIsNeededAndCanBe() {
        for (transfer in listOf(pq, hlg)) {
            assertTrue(HdrRule.asksForSdr(transfer, emptyList(), 33))
            assertTrue(HdrRule.asksForSdr(transfer, emptyList(), 36))
            assertFalse(HdrRule.asksForSdr(transfer, emptyList(), 32))
            assertFalse(HdrRule.asksForSdr(transfer, listOf(hdr10, hlgType), 36))
        }
        assertTrue(HdrRule.asksForSdr(hlg, listOf(hdr10), 33))
        assertFalse(HdrRule.asksForSdr(sdr, emptyList(), 36))
        assertFalse(HdrRule.asksForSdr(null, emptyList(), 36))
    }
}
