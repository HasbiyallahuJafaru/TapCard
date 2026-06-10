/**
 * Unit tests for NdefApduProcessor — the pure APDU state machine.
 *
 * Tests use a fake NdefPayloadProvider so there is no Android framework dependency.
 * Every test byte sequence mirrors the exact APDUs specified in .claude/NFC_SPEC.md.
 */
package com.tapcard.tapcard

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

class NdefApduProcessorTest {

    // ---------------------------------------------------------------------------
    // Test double
    // ---------------------------------------------------------------------------

    private class FakePayloadProvider(var url: String?) : NdefPayloadProvider {
        override fun getNdefUrlIfArmed(): String? = url
    }

    private lateinit var armed: FakePayloadProvider
    private lateinit var processor: NdefApduProcessor

    /** A stable test URL short enough for SR-format payload length byte. */
    private val testUrl = "https://tapcard.app/#dGVzdA"

    @Before
    fun setUp() {
        armed = FakePayloadProvider(testUrl)
        processor = NdefApduProcessor(armed)
    }

    // ---------------------------------------------------------------------------
    // Helper builders matching NFC_SPEC.md exact command bytes
    // ---------------------------------------------------------------------------

    /** SELECT AID: 00 A4 04 00 07 D2 76 00 00 85 01 01 00 */
    private val selectAid = byteArrayOf(
        0x00, 0xA4.toByte(), 0x04, 0x00, 0x07,
        0xD2.toByte(), 0x76, 0x00, 0x00, 0x85.toByte(), 0x01, 0x01,
        0x00
    )

    /** SELECT CC file: 00 A4 00 0C 02 E1 03 */
    private val selectCc = byteArrayOf(0x00, 0xA4.toByte(), 0x00, 0x0C, 0x02, 0xE1.toByte(), 0x03)

    /** SELECT NDEF file: 00 A4 00 0C 02 E1 04 */
    private val selectNdef = byteArrayOf(0x00, 0xA4.toByte(), 0x00, 0x0C, 0x02, 0xE1.toByte(), 0x04)

    /** READ BINARY CC: 00 B0 00 00 0F */
    private val readCc = byteArrayOf(0x00, 0xB0.toByte(), 0x00, 0x00, 0x0F)

    /** READ BINARY NDEF length: 00 B0 00 00 02 */
    private val readNdefLength = byteArrayOf(0x00, 0xB0.toByte(), 0x00, 0x00, 0x02)

    /** READ BINARY NDEF body: 00 B0 00 02 [le] */
    private fun readNdefBody(le: Int) = byteArrayOf(0x00, 0xB0.toByte(), 0x00, 0x02, le.toByte())

    // ---------------------------------------------------------------------------
    // Happy path: full SELECT AID → SELECT CC → READ CC → SELECT NDEF → READ
    // ---------------------------------------------------------------------------

    @Test
    fun `SELECT AID returns 9000 when armed`() {
        val response = processor.process(selectAid)
        assertArrayEquals(NdefApduProcessor.SW_OK, response)
    }

    @Test
    fun `SELECT CC returns 9000 after SELECT AID`() {
        processor.process(selectAid)
        val response = processor.process(selectCc)
        assertArrayEquals(NdefApduProcessor.SW_OK, response)
    }

    @Test
    fun `READ CC returns 15-byte CC file plus 9000`() {
        processor.process(selectAid)
        processor.process(selectCc)
        val response = processor.process(readCc)

        // Response must be 17 bytes: 15-byte CC + SW 90 00
        assertEquals(17, response.size)

        // CC length field at [0-1] must be 00 0F
        assertEquals(0x00.toByte(), response[0])
        assertEquals(0x0F.toByte(), response[1])

        // NFC Forum mapping version at [2] must be 0x20
        assertEquals(0x20.toByte(), response[2])

        // NDEF file ID at [9-10] must be E1 04
        assertEquals(0xE1.toByte(), response[9])
        assertEquals(0x04.toByte(), response[10])

        // Status word at the end
        assertEquals(0x90.toByte(), response[15])
        assertEquals(0x00.toByte(), response[16])
    }

    @Test
    fun `SELECT NDEF returns 9000 after SELECT CC`() {
        processor.process(selectAid)
        processor.process(selectCc)
        val response = processor.process(selectNdef)
        assertArrayEquals(NdefApduProcessor.SW_OK, response)
    }

    @Test
    fun `READ NDEF length returns 2-byte length plus 9000`() {
        processor.process(selectAid)
        processor.process(selectCc)
        processor.process(selectNdef)
        val response = processor.process(readNdefLength)

        // Response: [len_hi][len_lo] 90 00 = 4 bytes
        assertEquals(4, response.size)
        assertEquals(0x90.toByte(), response[2])
        assertEquals(0x00.toByte(), response[3])
    }

    @Test
    fun `READ NDEF body returns NDEF message bytes plus 9000`() {
        processor.process(selectAid)
        processor.process(selectCc)
        processor.process(selectNdef)

        // First get the length
        val lengthResponse = processor.process(readNdefLength)
        val ndefLen = ((lengthResponse[0].toInt() and 0xFF) shl 8) or (lengthResponse[1].toInt() and 0xFF)

        // Now read the body
        val bodyResponse = processor.process(readNdefBody(ndefLen))

        // Response: [ndefLen bytes] + SW = ndefLen + 2 bytes
        assertEquals(ndefLen + 2, bodyResponse.size)
        assertEquals(0x90.toByte(), bodyResponse[ndefLen])
        assertEquals(0x00.toByte(), bodyResponse[ndefLen + 1])

        // NDEF header byte must be 0xD1 (MB=1 ME=1 CF=0 SR=1 IL=0 TNF=001)
        assertEquals(0xD1.toByte(), bodyResponse[0])

        // Type length = 0x01
        assertEquals(0x01.toByte(), bodyResponse[1])

        // Type = 0x55 ("U")
        assertEquals(0x55.toByte(), bodyResponse[3])

        // URI prefix code = 0x04 ("https://")
        assertEquals(0x04.toByte(), bodyResponse[4])
    }

    @Test
    fun `full happy path NDEF body contains correct URL without https prefix`() {
        processor.process(selectAid)
        processor.process(selectCc)
        processor.process(selectNdef)

        val lengthResponse = processor.process(readNdefLength)
        val ndefLen = ((lengthResponse[0].toInt() and 0xFF) shl 8) or (lengthResponse[1].toInt() and 0xFF)
        val bodyResponse = processor.process(readNdefBody(ndefLen))

        // Payload bytes start at index 4 (after header, type-len, payload-len, type byte)
        val urlBodyBytes = bodyResponse.copyOfRange(5, ndefLen)
        val urlBody = String(urlBodyBytes, Charsets.UTF_8)
        val expectedBody = testUrl.removePrefix("https://")
        assertEquals(expectedBody, urlBody)
    }

    // ---------------------------------------------------------------------------
    // Disarmed service
    // ---------------------------------------------------------------------------

    @Test
    fun `SELECT AID returns 6982 when disarmed`() {
        armed.url = null
        val response = processor.process(selectAid)
        assertArrayEquals(NdefApduProcessor.SW_SECURITY_STATUS_NOT_SATISFIED, response)
    }

    @Test
    fun `SELECT AID returns 6982 after payload expires mid-session`() {
        // Start armed
        processor.process(selectAid)
        processor.process(selectCc)
        // Simulate expiry by flipping the provider
        armed.url = null
        // New SELECT AID (e.g. reader tries again) — should be rejected
        processor.reset()
        val response = processor.process(selectAid)
        assertArrayEquals(NdefApduProcessor.SW_SECURITY_STATUS_NOT_SATISFIED, response)
    }

    // ---------------------------------------------------------------------------
    // Wrong state guards
    // ---------------------------------------------------------------------------

    @Test
    fun `READ BINARY before SELECT AID returns 6982`() {
        val response = processor.process(readCc)
        assertArrayEquals(NdefApduProcessor.SW_SECURITY_STATUS_NOT_SATISFIED, response)
    }

    @Test
    fun `SELECT NDEF without SELECT CC first returns 6982`() {
        processor.process(selectAid)
        // Skip SELECT CC
        val response = processor.process(selectNdef)
        assertArrayEquals(NdefApduProcessor.SW_SECURITY_STATUS_NOT_SATISFIED, response)
    }

    @Test
    fun `SELECT CC without SELECT AID first returns 6982`() {
        val response = processor.process(selectCc)
        assertArrayEquals(NdefApduProcessor.SW_SECURITY_STATUS_NOT_SATISFIED, response)
    }

    // ---------------------------------------------------------------------------
    // Unknown / malformed commands
    // ---------------------------------------------------------------------------

    @Test
    fun `unknown INS returns 6D00`() {
        // 00 FF ... — INS = 0xFF is not SELECT or READ BINARY
        val unknownCmd = byteArrayOf(0x00, 0xFF.toByte(), 0x00, 0x00)
        val response = processor.process(unknownCmd)
        assertArrayEquals(NdefApduProcessor.SW_UNKNOWN, response)
    }

    @Test
    fun `non-standard CLA returns 6D00`() {
        val nonStdCla = byteArrayOf(0x80.toByte(), 0xA4.toByte(), 0x04, 0x00, 0x07,
            0xD2.toByte(), 0x76, 0x00, 0x00, 0x85.toByte(), 0x01, 0x01, 0x00)
        val response = processor.process(nonStdCla)
        assertArrayEquals(NdefApduProcessor.SW_UNKNOWN, response)
    }

    @Test
    fun `too-short APDU returns 6700`() {
        val tooShort = byteArrayOf(0x00, 0xA4.toByte(), 0x04) // only 3 bytes
        val response = processor.process(tooShort)
        assertArrayEquals(NdefApduProcessor.SW_WRONG_LENGTH, response)
    }

    @Test
    fun `wrong AID returns 6A82`() {
        val wrongAid = byteArrayOf(
            0x00, 0xA4.toByte(), 0x04, 0x00, 0x07,
            0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x00 // wrong AID bytes
        )
        val response = processor.process(wrongAid)
        assertArrayEquals(NdefApduProcessor.SW_FILE_NOT_FOUND, response)
    }

    // ---------------------------------------------------------------------------
    // NDEF message construction
    // ---------------------------------------------------------------------------

    @Test
    fun `buildNdefMessage produces correct header bytes`() {
        val ndefMessage = processor.buildNdefMessage("https://example.com/test")
        // 0xD1: MB=1 ME=1 CF=0 SR=1 IL=0 TNF=001
        assertEquals(0xD1.toByte(), ndefMessage[0])
        assertEquals(0x01.toByte(), ndefMessage[1]) // type length
        assertEquals(0x55.toByte(), ndefMessage[3]) // type = "U"
        assertEquals(0x04.toByte(), ndefMessage[4]) // URI prefix "https://"
    }

    @Test
    fun `buildNdefMessage payload length matches URL body byte count`() {
        val url = "https://tapcard.app/#abc"
        val body = url.removePrefix("https://")
        val ndefMessage = processor.buildNdefMessage(url)
        val payloadLen = ndefMessage[2].toInt() and 0xFF
        assertEquals(1 + body.toByteArray(Charsets.UTF_8).size, payloadLen) // 1 = prefix code byte
    }

    @Test
    fun `buildNdefMessage handles Unicode URL body correctly`() {
        val url = "https://tapcard.app/#مرحبا" // Arabic "مرحبا"
        val body = url.removePrefix("https://")
        val ndefMessage = processor.buildNdefMessage(url)
        val payloadBytes = ndefMessage.copyOfRange(5, ndefMessage.size)
        assertEquals(body, String(payloadBytes, Charsets.UTF_8))
    }

    // ---------------------------------------------------------------------------
    // Slice response helper
    // ---------------------------------------------------------------------------

    @Test
    fun `sliceResponse returns all bytes plus SW when le equals data length`() {
        val data = byteArrayOf(0x01, 0x02, 0x03)
        val response = processor.sliceResponse(data, 0, 3)
        assertArrayEquals(byteArrayOf(0x01, 0x02, 0x03, 0x90.toByte(), 0x00), response)
    }

    @Test
    fun `sliceResponse clips to remaining bytes when le exceeds data`() {
        val data = byteArrayOf(0x01, 0x02, 0x03)
        val response = processor.sliceResponse(data, 0, 10)
        assertArrayEquals(byteArrayOf(0x01, 0x02, 0x03, 0x90.toByte(), 0x00), response)
    }

    @Test
    fun `sliceResponse with offset returns correct slice`() {
        val data = byteArrayOf(0x01, 0x02, 0x03, 0x04)
        val response = processor.sliceResponse(data, 2, 2)
        assertArrayEquals(byteArrayOf(0x03, 0x04, 0x90.toByte(), 0x00), response)
    }

    @Test
    fun `sliceResponse with offset beyond data returns SW OK only`() {
        val data = byteArrayOf(0x01, 0x02)
        val response = processor.sliceResponse(data, 5, 2)
        assertArrayEquals(NdefApduProcessor.SW_OK, response)
    }
}
