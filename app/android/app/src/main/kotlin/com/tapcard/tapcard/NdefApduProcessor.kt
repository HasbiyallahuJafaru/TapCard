/**
 * Pure APDU state machine for NFC Forum Type 4 Tag emulation.
 *
 * Contains zero Android framework dependencies so it can be unit-tested with plain JUnit.
 * NdefHostApduService is the thin Android wrapper that feeds SharedPreferences data here.
 * This file owns all byte-level logic — NdefHostApduService owns all Android lifecycle logic.
 */
package com.tapcard.tapcard

/** Provides the current payload URL and arm validity to the processor. */
interface NdefPayloadProvider {
    /** Returns the NDEF vCard payload if armed and not expired; null otherwise. */
    fun getNdefPayloadIfArmed(): String?
}

/**
 * Stateful APDU command processor implementing the NFC Forum Type 4 Tag state machine.
 *
 * States: IDLE → SELECTED_APP → SELECTED_CC → SELECTED_NDEF
 * Create a new instance per NFC field session (reset on deactivation).
 *
 * @param payloadProvider supplies the URL payload and arm state on each command
 * @param onNdefServed    optional callback invoked once the NDEF body has been fully served
 *                        to the reader (i.e. a READ BINARY with offset ≥ 2 on the NDEF file
 *                        succeeded). Called at most once per processor instance. Safe to leave null.
 */
class NdefApduProcessor(
    private val payloadProvider: NdefPayloadProvider,
    private val onNdefServed: (() -> Unit)? = null,
) {

    companion object {
        // NFC Forum Type 4 Tag AID: D2 76 00 00 85 01 01
        val AID: ByteArray = byteArrayOf(0xD2.toByte(), 0x76, 0x00, 0x00, 0x85.toByte(), 0x01, 0x01)

        // File IDs
        val FILE_ID_CC:   ByteArray = byteArrayOf(0xE1.toByte(), 0x03) // Capability Container
        val FILE_ID_NDEF: ByteArray = byteArrayOf(0xE1.toByte(), 0x04) // NDEF file

        // Status words
        val SW_OK:                            ByteArray = byteArrayOf(0x90.toByte(), 0x00)
        val SW_UNKNOWN:                       ByteArray = byteArrayOf(0x6D, 0x00)
        val SW_SECURITY_STATUS_NOT_SATISFIED: ByteArray = byteArrayOf(0x69.toByte(), 0x82.toByte())
        val SW_FILE_NOT_FOUND:                ByteArray = byteArrayOf(0x6A.toByte(), 0x82.toByte())
        val SW_WRONG_LENGTH:                  ByteArray = byteArrayOf(0x67, 0x00)

        // APDU instruction bytes
        const val INS_SELECT:      Byte = 0xA4.toByte()
        const val INS_READ_BINARY: Byte = 0xB0.toByte()
        const val CLA_STANDARD:    Byte = 0x00.toByte()

        const val P1_SELECT_BY_NAME:     Byte = 0x04.toByte()
        const val P1_SELECT_BY_FILE_ID:  Byte = 0x00.toByte()
        const val P2_SELECT_NO_RESPONSE: Byte = 0x0C.toByte()
    }

    private enum class State { IDLE, SELECTED_APP, SELECTED_CC, SELECTED_NDEF }

    private var state = State.IDLE
    private var ndefBodyServed = false

    /**
     * Processes one APDU command and returns the response bytes.
     *
     * @param apdu Raw APDU command bytes from the NFC reader
     * @return Response APDU bytes (always ends in a 2-byte status word)
     */
    fun process(apdu: ByteArray): ByteArray {
        if (apdu.size < 4) return SW_WRONG_LENGTH

        val cla = apdu[0]
        val ins = apdu[1]
        val p1  = apdu[2]
        val p2  = apdu[3]

        if (cla != CLA_STANDARD) return SW_UNKNOWN

        return when (ins) {
            INS_SELECT      -> handleSelect(apdu, p1, p2)
            INS_READ_BINARY -> handleReadBinary(apdu, p1, p2)
            else            -> SW_UNKNOWN
        }
    }

    /** Resets state machine to IDLE. Call on NFC field deactivation. */
    fun reset() {
        state = State.IDLE
        ndefBodyServed = false
    }

    // -----------------------------------------------------------------------
    // SELECT handling
    // -----------------------------------------------------------------------

    private fun handleSelect(apdu: ByteArray, p1: Byte, p2: Byte): ByteArray {
        return when {
            p1 == P1_SELECT_BY_NAME -> handleSelectAid(apdu)
            p1 == P1_SELECT_BY_FILE_ID && p2 == P2_SELECT_NO_RESPONSE -> handleSelectFile(apdu)
            else -> SW_UNKNOWN
        }
    }

    /**
     * SELECT Application by AID (00 A4 04 00 07 <AID> 00).
     * Checks arm state — returns 69 82 if disarmed or expired.
     */
    private fun handleSelectAid(apdu: ByteArray): ByteArray {
        // Must check arm state before accepting the AID selection
        if (payloadProvider.getNdefPayloadIfArmed() == null) {
            state = State.IDLE
            return SW_SECURITY_STATUS_NOT_SATISFIED
        }

        val lc = if (apdu.size > 4) apdu[4].toInt() and 0xFF else 0
        if (apdu.size < 5 + lc) return SW_WRONG_LENGTH

        val aid = apdu.copyOfRange(5, 5 + lc)
        if (!aid.contentEquals(AID)) return SW_FILE_NOT_FOUND

        state = State.SELECTED_APP
        return SW_OK
    }

    /**
     * SELECT File by file ID (00 A4 00 0C 02 <FileID>).
     * Transitions SELECTED_APP→SELECTED_CC or SELECTED_CC→SELECTED_NDEF.
     */
    private fun handleSelectFile(apdu: ByteArray): ByteArray {
        val lc = if (apdu.size > 4) apdu[4].toInt() and 0xFF else 0
        if (apdu.size < 5 + lc) return SW_WRONG_LENGTH
        val fileId = apdu.copyOfRange(5, 5 + lc)

        return when {
            fileId.contentEquals(FILE_ID_CC) -> {
                if (state != State.SELECTED_APP) return SW_SECURITY_STATUS_NOT_SATISFIED
                state = State.SELECTED_CC
                SW_OK
            }
            fileId.contentEquals(FILE_ID_NDEF) -> {
                if (state != State.SELECTED_CC) return SW_SECURITY_STATUS_NOT_SATISFIED
                state = State.SELECTED_NDEF
                SW_OK
            }
            else -> SW_FILE_NOT_FOUND
        }
    }

    // -----------------------------------------------------------------------
    // READ BINARY handling
    // -----------------------------------------------------------------------

    private fun handleReadBinary(apdu: ByteArray, p1: Byte, p2: Byte): ByteArray {
        val offset = ((p1.toInt() and 0xFF) shl 8) or (p2.toInt() and 0xFF)
        // ISO 7816-4 §12.1: Le=0x00 in short form means Ne=256 ("give me up to 256 bytes").
        // Treating it as 0 would return empty data — fatal for readers that use Le=0 to mean "all".
        val leRaw  = if (apdu.size > 4) apdu[4].toInt() and 0xFF else 0
        val le     = if (leRaw == 0) 256 else leRaw

        return when (state) {
            State.SELECTED_CC   -> buildCcResponse(offset, le)
            State.SELECTED_NDEF -> buildNdefResponse(offset, le)
            else                -> SW_SECURITY_STATUS_NOT_SATISFIED
        }
    }

    /**
     * CC file (15 bytes): capability container per NFC Forum Type 4 Tag spec §7.2.1.
     * Max NDEF size field is dynamically calculated from actual payload length.
     */
    private fun buildCcResponse(offset: Int, le: Int): ByteArray {
        val vCard       = payloadProvider.getNdefPayloadIfArmed() ?: return SW_SECURITY_STATUS_NOT_SATISFIED
        val ndefMessage = buildNdefMessage(vCard)
        val maxNdefSize = ndefMessage.size + 2

        val ccFile = byteArrayOf(
            0x00, 0x0F,                                      // CC length = 15
            0x20,                                            // mapping version 2.0
            0x00, 0xFF.toByte(),                             // max R-APDU = 255 (fits any normal vCard in one read)
            0x00, 0x7F,                                      // max C-APDU = 127
            0x04,                                            // NDEF file control TLV tag
            0x06,                                            // NDEF file control TLV length
            0xE1.toByte(), 0x04,                             // NDEF file ID
            ((maxNdefSize shr 8) and 0xFF).toByte(),         // max NDEF size hi
            (maxNdefSize and 0xFF).toByte(),                 // max NDEF size lo
            0x00,                                            // read access: open
            0x00                                             // write access: open
        )
        return sliceResponse(ccFile, offset, le)
    }

    /**
     * NDEF file: [2-byte length][NDEF message bytes].
     * offset=0,le=2 → length field. offset=2,le=N → message body.
     *
     * Invokes [onNdefServed] once the body (offset ≥ 2) has been successfully returned,
     * signalling that the remote reader has received the full NDEF payload.
     */
    private fun buildNdefResponse(offset: Int, le: Int): ByteArray {
        val vCard       = payloadProvider.getNdefPayloadIfArmed() ?: return SW_SECURITY_STATUS_NOT_SATISFIED
        val ndefMessage = buildNdefMessage(vCard)
        val ndefLen     = ndefMessage.size

        val ndefFile = byteArrayOf(
            ((ndefLen shr 8) and 0xFF).toByte(),
            (ndefLen and 0xFF).toByte()
        ) + ndefMessage

        val response = sliceResponse(ndefFile, offset, le)

        // Fire onNdefServed only when the response covers the LAST byte of the NDEF file.
        // Firing on the first body read (old behaviour) was wrong for vCards that require
        // multiple READ BINARY commands: the disarm would cause subsequent reads to fail.
        val servedUpTo = minOf(offset + le, ndefFile.size)
        if (!ndefBodyServed && offset >= 2 && servedUpTo >= ndefFile.size) {
            ndefBodyServed = true
            onNdefServed?.invoke()
        }

        return response
    }

    /**
     * Builds an NDEF MIME record carrying a vCard 3.0 payload.
     * TNF=0x02 (MIME), type="text/vcard", SR bit set when payload ≤ 255 bytes.
     *
     * Phones receiving this record prompt "Add to Contacts" directly — no browser.
     *
     * @param vCard Raw vCard 3.0 string (UTF-8, CRLF line endings)
     * @return Raw NDEF message bytes
     */
    internal fun buildNdefMessage(vCard: String): ByteArray {
        // "text/vcard" (no x- prefix) is required: iOS 14.5+ only triggers "Add to Contacts"
        // for the standard MIME type. "text/x-vcard" is silently ignored by Apple's NFC stack.
        val typeBytes    = "text/vcard".toByteArray(Charsets.US_ASCII)
        val payloadBytes = vCard.toByteArray(Charsets.UTF_8)
        val typeLen      = typeBytes.size        // 10
        val payloadLen   = payloadBytes.size

        // Use SR (short record) bit when payload fits in one byte, else 4-byte length.
        val useSR = payloadLen <= 255

        // NDEF record header: MB=1 ME=1 CF=0 SR=? IL=0 TNF=010
        // SR=1 → 0xD2, SR=0 → 0xC2
        val header = if (useSR) 0xD2.toByte() else 0xC2.toByte()

        val headerBytes = if (useSR) {
            byteArrayOf(
                header,
                typeLen.toByte(),
                payloadLen.toByte(),
            )
        } else {
            byteArrayOf(
                header,
                typeLen.toByte(),
                ((payloadLen shr 24) and 0xFF).toByte(),
                ((payloadLen shr 16) and 0xFF).toByte(),
                ((payloadLen shr 8)  and 0xFF).toByte(),
                (payloadLen          and 0xFF).toByte(),
            )
        }

        return headerBytes + typeBytes + payloadBytes
    }

    /**
     * Returns a slice of [data] from [offset] for up to [le] bytes, with SW_OK appended.
     * If le exceeds remaining bytes, all remaining bytes are returned (no padding).
     */
    internal fun sliceResponse(data: ByteArray, offset: Int, le: Int): ByteArray {
        if (offset >= data.size) return SW_OK
        val end     = minOf(offset + le, data.size)
        val payload = data.copyOfRange(offset, end)
        return payload + SW_OK
    }
}
