package io.tastecard.ui

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.outlined.WaterDrop
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import io.tastecard.model.EmergentTheme
import io.tastecard.model.Tastecard
import java.io.File
import kotlinx.coroutines.launch

private val LIGHT_INK = Color(0xFFFDF9F6)
private val DARK_INK = Color(0xFF0C1519)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CardScreen(vm: TastecardViewModel, card: Tastecard) {
    val palette = paletteAt(card.themeIndex)
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var selectedThemeId by remember(card.id) { mutableStateOf<String?>(null) }
    var detail by remember { mutableStateOf<EmergentTheme?>(null) }
    var showSettings by remember { mutableStateOf(false) }
    var showAppearance by remember { mutableStateOf(false) }
    var sharing by remember { mutableStateOf(false) }

    // Appearance overrides.
    val customColor = card.customBackgroundColorArgb?.let { Color(it.toInt()) }
    val bgPhoto = card.customBackgroundPath
    val baseColor = customColor ?: palette.background
    val mult = card.glassTintMultiplier.toFloat()

    val ink: Color = when {
        bgPhoto != null -> LIGHT_INK
        customColor != null -> if (Brightness.isDark(customColor)) LIGHT_INK else DARK_INK
        else -> palette.text
    }
    val glassFill: Color = when {
        customColor != null ->
            (if (Brightness.isDark(customColor)) Color.White else Color.Black)
                .copy(alpha = (if (Brightness.isDark(customColor)) 0.16f else 0.06f) * mult)
        bgPhoto != null -> Color.White.copy(alpha = 0.12f * mult)
        else -> palette.glassFill.copy(alpha = palette.glassFill.alpha * mult)
    }
    val glassBorder: Color = when {
        customColor != null -> if (Brightness.isDark(customColor)) Color.White.copy(0.22f) else Color.Black.copy(0.12f)
        bgPhoto != null -> Color.White.copy(0.30f)
        else -> palette.glassBorder
    }

    val profileLauncher = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) vm.setProfilePhoto(uri)
    }
    val bgLauncher = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) vm.setBackgroundPhoto(uri)
    }
    val imageRequest = PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)

    Box(Modifier.fillMaxSize().background(baseColor), contentAlignment = Alignment.Center) {
        if (bgPhoto != null) {
            AsyncImage(File(bgPhoto), contentDescription = null,
                modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.35f)))
        }
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).systemBarsPadding().padding(16.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(
                Modifier.fillMaxWidth().glass(glassFill, glassBorder, 40.dp).padding(22.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp),
            ) {
                // Header: settings • brand • appearance (droplet).
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    RoundIcon(Icons.Filled.Settings, ink) { showSettings = true }
                    Spacer(Modifier.width(8.dp))
                    Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                        Mono("TASTECARD", ink.copy(alpha = 0.9f), 12, FontWeight.Bold, 3.0)
                    }
                    RoundIcon(Icons.Outlined.WaterDrop, ink) { showAppearance = true }
                }

                // Identity: profile picture + possessive title + rarity.
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    ProfileAvatar(card.profileImagePath, ink, 56.dp) { profileLauncher.launch(imageRequest) }
                    Column {
                        Text(card.cardTitle, color = ink, fontSize = 26.sp, fontWeight = FontWeight.Bold, maxLines = 2)
                        Spacer(Modifier.height(4.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Mono("TASTECARD RARITY: ", ink.copy(alpha = 0.6f), 10)
                            RarityBadge(card.cardRarity, 12)
                        }
                    }
                }

                // Stats
                Row(Modifier.fillMaxWidth()) {
                    Stat(card.photosAnalysed.abbreviated(), "PHOTOS", ink, Modifier.weight(1f))
                    Stat(card.emergentThemeCount.toString(), "EMERGING THEMES", ink, Modifier.weight(1f))
                    Stat(card.placesCount.toString(), "PLACES", ink, Modifier.weight(1f))
                }

                // About Me (replaces the category chips).
                AboutMeSection(card.aboutMe, ink) { showSettings = true }

                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Mono("EMERGENT THEMES", ink.copy(alpha = 0.9f), 13, FontWeight.Bold, 3.0)
                }

                // Grid 2-col
                card.themes.chunked(2).forEach { rowThemes ->
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        rowThemes.forEach { theme ->
                            val highlighted = selectedThemeId == null || selectedThemeId == theme.categoryId
                            ThemeCard(theme, highlighted, Modifier.weight(1f)) { detail = theme }
                        }
                        if (rowThemes.size == 1) Spacer(Modifier.weight(1f))
                    }
                }

                // Share
                Box(
                    Modifier.fillMaxWidth()
                        .glass(Color.White.copy(alpha = 0.15f), Color.White.copy(alpha = 0.35f), 16.dp)
                        .clickable(enabled = !sharing) {
                            sharing = true
                            scope.launch {
                                val uri = SnapshotRenderer.renderToShareUri(context, card)
                                sharing = false
                                if (uri != null) shareImage(context, uri)
                                else vm.showToast("Couldn't create the image")
                            }
                        }
                        .padding(vertical = 14.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(if (sharing) "PREPARING…" else "SHARE TASTECARD",
                        color = ink, fontWeight = FontWeight.Black, fontSize = 12.sp, letterSpacing = 2.sp)
                }

                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Mono("${card.cardTitle} • ${card.serialDisplay}".uppercase(), ink.copy(alpha = 0.4f), 10, letter = 2.0)
                }
            }
        }
    }

    detail?.let { theme ->
        ModalBottomSheet(onDismissRequest = { detail = null }, containerColor = Color(0xFF0B1220)) {
            DetailContent(theme, vm) { detail = null }
        }
    }

    if (showSettings) {
        ModalBottomSheet(onDismissRequest = { showSettings = false }, containerColor = Color(0xFF0B1220)) {
            SettingsContent(vm, card, onPickProfile = { profileLauncher.launch(imageRequest) }, onClose = { showSettings = false })
        }
    }

    if (showAppearance) {
        ModalBottomSheet(onDismissRequest = { showAppearance = false }, containerColor = Color(0xFF0B1220)) {
            AppearanceContent(vm, card, onPickBackground = { bgLauncher.launch(imageRequest) }, onClose = { showAppearance = false })
        }
    }
}

@Composable
private fun ProfileAvatar(path: String?, ink: Color, size: androidx.compose.ui.unit.Dp, onClick: () -> Unit) {
    Box(
        Modifier.size(size).clip(CircleShape).background(ink.copy(alpha = 0.12f)).clickable { onClick() },
        contentAlignment = Alignment.Center,
    ) {
        if (path != null) {
            AsyncImage(File(path), contentDescription = "Profile photo",
                modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
        } else {
            Icon(Icons.Filled.Person, contentDescription = "Add profile photo",
                tint = ink.copy(alpha = 0.55f), modifier = Modifier.size(size * 0.5f))
        }
    }
}

@Composable
private fun AboutMeSection(about: String?, ink: Color, onEdit: () -> Unit) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Mono("ABOUT ME", ink.copy(alpha = 0.7f), 11, FontWeight.Bold, 2.0)
        if (!about.isNullOrEmpty()) {
            Text(about, color = ink.copy(alpha = 0.9f), fontSize = 14.sp)
        } else {
            Text("Add yours in Settings", color = ink.copy(alpha = 0.45f), fontSize = 14.sp,
                fontStyle = FontStyle.Italic, modifier = Modifier.clickable { onEdit() })
        }
    }
}

@Composable
private fun RoundIcon(icon: androidx.compose.ui.graphics.vector.ImageVector, tint: Color, onClick: () -> Unit) {
    Box(
        Modifier.size(36.dp).clip(CircleShape).background(tint.copy(alpha = 0.10f)).clickable { onClick() },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(18.dp))
    }
}

@Composable
private fun Stat(value: String, label: String, color: Color, modifier: Modifier) {
    Column(modifier) {
        Text(value, color = color, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Black, fontSize = 18.sp)
        Text(label, color = color.copy(alpha = 0.7f), fontSize = 9.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
    }
}

@Composable
private fun ThemeCard(theme: EmergentTheme, highlighted: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier
            .aspectRatio(3f / 4f)
            .clip(RoundedCornerShape(24.dp))
            .clickable { onClick() }
    ) {
        AssetImage(theme.heroPhotoUri, Modifier.fillMaxSize())
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.85f)))
            )
        )
        Text(
            theme.displayName, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Medium,
            modifier = Modifier.align(Alignment.BottomStart).padding(12.dp),
        )
        if (!highlighted) {
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.45f)))
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DetailContent(theme: EmergentTheme, vm: TastecardViewModel, onClose: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var sharing by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Mono(theme.displayName.uppercase(), Color.White.copy(alpha = 0.9f), 12, FontWeight.Bold, 2.0)
        Box(Modifier.fillMaxWidth().aspectRatio(4f / 3f).clip(RoundedCornerShape(16.dp))) {
            AssetImage(theme.heroPhotoUri, Modifier.fillMaxSize())
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(theme.displayName, color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.weight(1f))
            Text("${theme.photoCount}", color = Color.White, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.SemiBold)
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Theme rarity: ", color = Color.White.copy(alpha = 0.6f), fontSize = 12.sp)
            RarityBadge(theme.rarityTier, 12)
        }
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.05f)).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Mono("ATLAS INSIGHT", Color.White.copy(alpha = 0.6f), 10, letter = 1.0)
            if (theme.tagline.isNotEmpty()) {
                Text(theme.tagline, color = Color.White.copy(alpha = 0.9f), fontSize = 15.sp)
            }
            Text("Seen across ${theme.photoCount} of your photos.", color = Color.White.copy(alpha = 0.55f), fontSize = 12.sp)
        }
        // Share this single theme as its own punchy 9:16 card (mirrors iOS "Share this theme").
        Box(
            Modifier.fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(Brush.horizontalGradient(listOf(Color(0xFFEC4899), Color(0xFFE11D48))))
                .clickable(enabled = !sharing) {
                    val card = vm.card ?: return@clickable
                    sharing = true
                    scope.launch {
                        val uri = MiniThemeRenderer.renderToShareUri(context, card, theme)
                        sharing = false
                        if (uri != null) shareImage(context, uri) else vm.showToast("Couldn't create the image")
                    }
                }
                .padding(vertical = 14.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                if (sharing) "PREPARING…" else "SHARE THIS THEME",
                color = Color.White, fontWeight = FontWeight.Black, fontSize = 13.sp, letterSpacing = 1.sp,
            )
        }
        // "Change photo" — pick from this category's own matches (pick-from-matches parity).
        if (theme.candidatePhotoUris.size > 1) {
            Mono("CHANGE PHOTO", Color.White.copy(alpha = 0.6f), 10, letter = 1.0)
            androidx.compose.foundation.layout.FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                theme.candidatePhotoUris.take(9).forEach { uri ->
                    Box(
                        Modifier.size(64.dp).clip(RoundedCornerShape(10.dp))
                            .clickable { vm.swapHero(theme.categoryId, uri); onClose() }
                    ) { AssetImage(uri, Modifier.fillMaxSize()) }
                }
            }
        }
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun SettingsContent(vm: TastecardViewModel, card: Tastecard, onPickProfile: () -> Unit, onClose: () -> Unit) {
    var name by remember { mutableStateOf(card.displayName) }
    var about by remember { mutableStateOf(card.aboutMe ?: "") }
    var confirmDelete by remember { mutableStateOf(false) }

    Column(Modifier.fillMaxWidth().padding(20.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Mono("SETTINGS", Color.White.copy(alpha = 0.9f), 12, FontWeight.Bold, 2.0)

        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            ProfileAvatar(card.profileImagePath, Color.White, 44.dp, onPickProfile)
            TextButton(onClick = onPickProfile) { Text(if (card.profileImagePath == null) "Choose profile photo" else "Change profile photo") }
            if (card.profileImagePath != null) {
                TextButton(onClick = { vm.clearProfilePhoto() }) { Text("Remove", color = Color(0xFFFDA4AF)) }
            }
        }

        OutlinedTextField(
            value = name, onValueChange = { name = it },
            label = { Text("Your name") }, singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Text("Shown as “${Tastecard.title(name)}”.", color = Color.White.copy(alpha = 0.6f), fontSize = 12.sp)
        TextButton(onClick = { vm.rename(name) }) { Text("Save name") }

        OutlinedTextField(
            value = about, onValueChange = { about = it.take(io.tastecard.security.InputSanitizer.MAX_ABOUT_ME_LENGTH) },
            label = { Text("About me") },
            modifier = Modifier.fillMaxWidth(),
        )
        TextButton(onClick = { vm.setAboutMe(about) }) { Text("Save about me") }

        TextButton(onClick = { onClose(); vm.startAnalysis() }) { Text("Re-analyse my camera roll") }
        Text(
            "Tastecard analyses your photos on-device. Nothing is uploaded, stored off-device, or shared with third parties.",
            color = Color.White.copy(alpha = 0.6f), fontSize = 12.sp,
        )
        TextButton(onClick = { confirmDelete = true }) {
            Text("Delete my Tastecard data", color = Color(0xFFFDA4AF))
        }
        Spacer(Modifier.height(8.dp))
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            confirmButton = { TextButton(onClick = { confirmDelete = false; onClose(); vm.deleteData() }) { Text("Delete") } },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Cancel") } },
            title = { Text("Delete all data?") },
            text = { Text("This permanently removes your card and on-device cache.") },
        )
    }
}

@Composable
private fun AppearanceContent(vm: TastecardViewModel, card: Tastecard, onPickBackground: () -> Unit, onClose: () -> Unit) {
    // Seed the colour sliders from the current custom colour (or a pleasant default).
    val seedHsv = remember(card.customBackgroundColorArgb) {
        FloatArray(3).also { hsv ->
            val argb = card.customBackgroundColorArgb?.toInt() ?: Color(0xFF6C8EBF).toArgb()
            android.graphics.Color.colorToHSV(argb, hsv)
        }
    }
    var hue by remember { mutableFloatStateOf(seedHsv[0]) }
    var value by remember { mutableFloatStateOf(if (seedHsv[2] < 0.2f) 0.85f else seedHsv[2]) }
    var opacity by remember { mutableFloatStateOf(card.glassTintMultiplier.toFloat()) }
    val preview = Color.hsv(hue, 0.6f, value)

    fun applyColor() {
        vm.setCustomColor(preview.toArgb().toLong() and 0xFFFFFFFFL)
    }

    Column(Modifier.fillMaxWidth().padding(20.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Mono("APPEARANCE", Color.White.copy(alpha = 0.9f), 12, FontWeight.Bold, 2.0)

        Text("Background colour", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
        Box(Modifier.fillMaxWidth().height(40.dp).clip(RoundedCornerShape(12.dp)).background(preview))
        Text("Hue", color = Color.White.copy(alpha = 0.6f), fontSize = 11.sp)
        Slider(value = hue, onValueChange = { hue = it }, valueRange = 0f..360f, onValueChangeFinished = { applyColor() })
        Text("Brightness", color = Color.White.copy(alpha = 0.6f), fontSize = 11.sp)
        Slider(value = value, onValueChange = { value = it }, valueRange = 0.2f..1f, onValueChangeFinished = { applyColor() })

        TextButton(onClick = onPickBackground) { Text("Use a background photo") }
        if (card.customBackgroundPath != null) {
            TextButton(onClick = { vm.clearBackgroundPhoto() }) { Text("Remove background photo", color = Color(0xFFFDA4AF)) }
        }
        TextButton(onClick = { vm.drop() }) { Text("Shuffle palette") }

        Text("Card opacity", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
        Slider(value = opacity, onValueChange = { opacity = it }, valueRange = 0f..1f,
            onValueChangeFinished = { vm.setGlassOpacity(opacity.toDouble()) })
        Text("Lower is more see-through; higher is more frosted.", color = Color.White.copy(alpha = 0.5f), fontSize = 11.sp)

        TextButton(onClick = { vm.resetAppearance(); onClose() }) { Text("Reset appearance", color = Color(0xFFFDA4AF)) }
        Spacer(Modifier.height(8.dp))
    }
}

private fun shareImage(context: Context, uri: Uri) {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "image/png"
        putExtra(Intent.EXTRA_STREAM, uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    context.startActivity(Intent.createChooser(intent, "Share Tastecard"))
}
