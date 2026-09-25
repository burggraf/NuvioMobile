package com.nuvio.app.features.plugins

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFails

class PluginCryptoTest {
    @Test
    fun aesGcmMatchesNistVectorAndRejectsTamperedTag() {
        val key = ByteArray(16)
        val iv = ByteArray(12)
        val plaintext = ByteArray(16)

        val encrypted = pluginAesEncrypt("AES-GCM", key, iv, plaintext)

        assertEquals(
            "0388dace60b6a392f328c2b971b2fe78ab6e47d42cec13bdf53a67b21257bddf",
            encrypted.toHex(),
        )
        assertContentEquals(plaintext, pluginAesDecrypt("AES-GCM", key, iv, encrypted))

        val tampered = encrypted.copyOf().apply {
            this[lastIndex] = (this[lastIndex].toInt() xor 1).toByte()
        }
        assertFails { pluginAesDecrypt("AES-GCM", key, iv, tampered) }
    }

    @Test
    fun aes192GcmSupportsLongIv() {
        val key = ByteArray(24) { it.toByte() }
        val iv = ByteArray(16) { (it + 1).toByte() }
        val plaintext = "plugin crypto test".encodeToByteArray()

        val encrypted = pluginAesEncrypt("AES-GCM", key, iv, plaintext)

        assertEquals(plaintext.size + 16, encrypted.size)
        assertContentEquals(plaintext, pluginAesDecrypt("AES-GCM", key, iv, encrypted))
    }
}

private fun ByteArray.toHex(): String =
    joinToString(separator = "") { it.toUByte().toString(16).padStart(2, '0') }
