package io.tastecard.security

/** Display-name sanitisation + filename safety (§9) — ported from iOS. */
object InputSanitizer {
    const val MAX_DISPLAY_NAME_LENGTH = 40
    const val MAX_ABOUT_ME_LENGTH = 160

    private val FORMATTING = setOf(
        0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0xFEFF,
        0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
        0x2066, 0x2067, 0x2068, 0x2069,
    )

    fun displayName(raw: String): String {
        val filtered = buildString {
            for (cp in raw.codePoints()) {
                if (isDisallowed(cp)) continue
                appendCodePoint(cp)
            }
        }
        val collapsed = filtered.split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")
        val trimmed = collapsed.trim()
        return if (trimmed.length > MAX_DISPLAY_NAME_LENGTH) trimmed.substring(0, MAX_DISPLAY_NAME_LENGTH) else trimmed
    }

    fun displayNameOrDefault(raw: String, default: String = "My Rollcard"): String {
        val s = displayName(raw)
        return s.ifEmpty { default }
    }

    /** Free-text "About me": same stripping/whitespace collapse, longer cap, may be empty. */
    fun aboutMe(raw: String): String {
        val filtered = buildString {
            for (cp in raw.codePoints()) {
                if (isDisallowed(cp)) continue
                appendCodePoint(cp)
            }
        }
        val collapsed = filtered.split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ").trim()
        return if (collapsed.length > MAX_ABOUT_ME_LENGTH) collapsed.substring(0, MAX_ABOUT_ME_LENGTH) else collapsed
    }

    fun filenameSlug(raw: String): String {
        val lowered = displayName(raw).lowercase()
        val mapped = lowered.map { c -> if (c in 'a'..'z' || c in '0'..'9') c else '_' }.joinToString("")
        var slug = mapped
        while (slug.contains("__")) slug = slug.replace("__", "_")
        slug = slug.trim('_')
        return slug.ifEmpty { "rollcard" }
    }

    private fun isDisallowed(cp: Int): Boolean {
        if (cp < 0x20 || (cp in 0x7F..0x9F)) return true
        return FORMATTING.contains(cp)
    }
}
