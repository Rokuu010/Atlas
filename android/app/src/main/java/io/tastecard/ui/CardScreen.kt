package io.tastecard.ui

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.outlined.WaterDrop
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.tastecard.model.EmergentTheme
import io.tastecard.model.Tastecard
import kotlinx.coroutines.launch

@OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@Composable
fun CardScreen(vm: TastecardViewModel, card: Tastecard) {
    val palette = paletteAt(card.themeIndex)
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var selectedThemeId by remember(card.id) { mutableStateOf<String?>(null) }
    var detail by remember { mutableStateOf<EmergentTheme?>(null) }
    var showSettings by remember { mutableStateOf(false) }
    var sharing by remember { mutableStateOf(false) }

    Box(
        Modifier.fillMaxSize().background(palette.background),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).systemBarsPadding().padding(16.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(
                Modifier.fillMaxWidth().glass(palette.glassFill, palette.glassBorder, 40.dp).padding(22.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp),
            ) {
                // Header
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    RoundIcon(Icons.Filled.Settings, palette.text) { showSettings = true }
                    Spacer(Modifier.width(8.dp))
                    Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                        Mono("TASTECARD", palette.text.copy(alpha = 0.9f), 12, FontWeight.Bold, 3.0)
                    }
                    RoundIcon(Icons.Outlined.WaterDrop, palette.text) { vm.drop() }
                }

                // Name + rarity
                Column {
                    Text(card.displayName, color = palette.text, fontSize = 30.sp, fontWeight = FontWeight.Bold, maxLines = 2)
                    Spacer(Modifier.height(4.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Mono("TASTECARD RARITY: ", palette.text.copy(alpha = 0.6f), 10)
                        RarityBadge(card.cardRarity, 12)
                    }
                }

                // Stats
                Row(Modifier.fillMaxWidth()) {
                    Stat(card.photosAnalysed.abbreviated(), "PHOTOS", palette.text, Modifier.weight(1f))
                    Stat(card.emergentThemeCount.toString(), "EMERGING THEMES", palette.text, Modifier.weight(1f))
                    Stat(card.placesCount.toString(), "PLACES", palette.text, Modifier.weight(1f))
                }

                // Chips
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    card.themes.forEach { theme ->
                        val active = selectedThemeId == theme.categoryId
                        Box(
                            Modifier
                                .clip(RoundedCornerShape(50))
                                .background(Color.White.copy(alpha = if (active) 0.35f else 0.10f))
                                .clickable { selectedThemeId = if (active) null else theme.categoryId }
                                .padding(horizontal = 14.dp, vertical = 6.dp)
                        ) {
                            Text(theme.displayName, color = palette.text, fontSize = 12.sp,
                                fontWeight = if (active) FontWeight.Bold else FontWeight.Normal)
                        }
                    }
                }

                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Mono("EMERGENT THEMES", palette.text.copy(alpha = 0.9f), 13, FontWeight.Bold, 3.0)
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
                        color = palette.text, fontWeight = FontWeight.Black, fontSize = 12.sp, letterSpacing = 2.sp)
                }

                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Mono("${card.displayName} • ${card.serialDisplay}".uppercase(), palette.text.copy(alpha = 0.4f), 10, letter = 2.0)
                }
            }
        }
    }

    detail?.let { theme ->
        ModalBottomSheet(onDismissRequest = { detail = null }, containerColor = Color(0xFF0B1220)) {
            DetailContent(theme)
        }
    }

    if (showSettings) {
        ModalBottomSheet(onDismissRequest = { showSettings = false }, containerColor = Color(0xFF0B1220)) {
            SettingsContent(vm, card, onClose = { showSettings = false })
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

@Composable
private fun DetailContent(theme: EmergentTheme) {
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
            Text(theme.tagline, color = Color.White.copy(alpha = 0.9f), fontSize = 15.sp)
            Text("Seen across ${theme.photoCount} of your photos.", color = Color.White.copy(alpha = 0.55f), fontSize = 12.sp)
        }
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun SettingsContent(vm: TastecardViewModel, card: Tastecard, onClose: () -> Unit) {
    var name by remember { mutableStateOf(card.displayName) }
    var confirmDelete by remember { mutableStateOf(false) }

    Column(Modifier.fillMaxWidth().padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Mono("SETTINGS", Color.White.copy(alpha = 0.9f), 12, FontWeight.Bold, 2.0)
        OutlinedTextField(
            value = name, onValueChange = { name = it },
            label = { Text("Display name") }, singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        TextButton(onClick = { vm.rename(name); onClose() }) { Text("Save name") }
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

private fun shareImage(context: Context, uri: Uri) {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "image/png"
        putExtra(Intent.EXTRA_STREAM, uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    context.startActivity(Intent.createChooser(intent, "Share Tastecard"))
}
