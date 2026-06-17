package io.tastecard.ui

import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import io.tastecard.model.RarityTier

/** The 16 themes, ported from the iOS AppTheme (exact hex + glass opacities). */
data class AppPalette(
    val name: String,
    val background: Color,
    val text: Color,
    val glassFill: Color,
    val glassBorder: Color,
)

private fun w(a: Double) = Color.White.copy(alpha = a.toFloat())
private fun b(a: Double) = Color.Black.copy(alpha = a.toFloat())

val APP_PALETTES: List<AppPalette> = listOf(
    AppPalette("Cream", Color(0xFFF3E5C3), Color(0xFF0C1519), w(0.10), w(0.25)),
    AppPalette("China Rose", Color(0xFFA24C61), Color(0xFFFDF9F6), w(0.05), w(0.15)),
    AppPalette("Kobi", Color(0xFFE2A9C0), Color(0xFF411528), w(0.10), w(0.20)),
    AppPalette("Queen Pink", Color(0xFFE1C9D5), Color(0xFF411528), w(0.10), w(0.20)),
    AppPalette("Chocolate Kisses", Color(0xFF411528), Color(0xFFFFEFF5), w(0.05), w(0.10)),
    AppPalette("Persian Plum", Color(0xFF710C21), Color(0xFFFDF0F3), b(0.20), w(0.15)),
    AppPalette("Jacarta", Color(0xFF3F2A52), Color(0xFFF5EFFF), w(0.05), w(0.10)),
    AppPalette("Dark Blue-Gray", Color(0xFF75619D), Color(0xFFFFFFFF), w(0.05), w(0.15)),
    AppPalette("Wisteria", Color(0xFFBEAEDB), Color(0xFF3F2A52), w(0.10), w(0.20)),
    AppPalette("Bright Gray", Color(0xFFE6EFF7), Color(0xFF3A2D34), w(0.15), w(0.30)),
    AppPalette("Black Coffee", Color(0xFF3A2D34), Color(0xFFF0EBF2), w(0.05), w(0.10)),
    AppPalette("Cadet Grey", Color(0xFF959BB5), Color(0xFF0A1123), w(0.10), w(0.20)),
    AppPalette("Chinese Black", Color(0xFF0A1123), Color(0xFFE6EFF7), w(0.05), w(0.10)),
    AppPalette("American Blue", Color(0xFF3A3E6C), Color(0xFFE6EFF7), w(0.05), w(0.10)),
    AppPalette("Ube", Color(0xFF8387C3), Color(0xFF0A1123), w(0.10), w(0.20)),
    AppPalette("Cool Grey", Color(0xFF8A8CAC), Color(0xFF0A1123), w(0.10), w(0.20)),
)

fun paletteAt(index: Int): AppPalette {
    val n = APP_PALETTES.size
    return APP_PALETTES[((index % n) + n) % n]
}

/** "The drop": next random index that is never the current one. */
fun nextDropIndex(current: Int): Int {
    if (APP_PALETTES.size <= 1) return current
    var next = current
    while (next == current) next = APP_PALETTES.indices.random()
    return next
}

object RarityGradients {
    fun colors(tier: RarityTier): List<Color> = when (tier) {
        RarityTier.COMMON -> listOf(Color(0xFFA1A1AA), Color(0xFFE4E4E7), Color(0xFF71717A))
        RarityTier.RARE -> listOf(Color(0xFFFBBF24), Color(0xFFFDA4AF), Color(0xFFD97706))
        RarityTier.EPIC -> listOf(Color(0xFFE879F9), Color(0xFFFBCFE8), Color(0xFF8B5CF6))
        RarityTier.LEGENDARY -> listOf(Color(0xFF34D399), Color(0xFFCCFBF1), Color(0xFFF59E0B))
    }

    fun brush(tier: RarityTier): Brush = Brush.horizontalGradient(colors(tier))
}
