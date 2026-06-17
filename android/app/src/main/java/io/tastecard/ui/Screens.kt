package io.tastecard.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.collectAsState
import io.tastecard.engine.WarmingReason

@Composable
fun ToastBar(message: String) {
    Box(
        Modifier
            .clip(androidx.compose.foundation.shape.RoundedCornerShape(50))
            .background(Color(0xFF0C1519).copy(alpha = 0.95f))
            .padding(horizontal = 24.dp, vertical = 12.dp)
    ) {
        Text(message, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Medium)
    }
}

@Composable
fun GreetingScreen(onStart: () -> Unit) {
    OnboardingBackground {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().padding(horizontal = 32.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Mono("TASTECARD", Color.White.copy(alpha = 0.75f), 13, FontWeight.Bold, 4.0)
            Spacer(Modifier.height(16.dp))
            Text(
                "Find out what your\ncamera roll says about you",
                color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center, lineHeight = 38.sp,
            )
            Spacer(Modifier.height(14.dp))
            Text(
                "Analysed entirely on your device. Nothing is ever uploaded.",
                color = Color.White.copy(alpha = 0.7f), fontSize = 14.sp, textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(36.dp))
            CTAButton("Create my Tastecard", onClick = onStart)
        }
    }
}

@Composable
fun PrimingScreen(onContinue: () -> Unit, onBack: () -> Unit) {
    OnboardingBackground {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().padding(horizontal = 28.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("Before we look at your photos", color = Color.White, fontSize = 23.sp,
                fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
            Spacer(Modifier.height(20.dp))
            Column(
                Modifier.fillMaxWidth().glass(Color.White.copy(alpha = 0.06f), Color.White.copy(alpha = 0.12f), 24.dp)
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Bullet("Stays on your device", "Your photos are analysed locally. Nothing is uploaded — ever.")
                Bullet("Nothing sensitive is sent", "We never transmit your photos, screenshots, or their contents.")
                Bullet("All or only selected photos", "You choose how much access to grant on the next screen.")
            }
            Spacer(Modifier.height(28.dp))
            CTAButton("Continue", onClick = onContinue)
            Spacer(Modifier.height(8.dp))
            SecondaryButton("Not now", onClick = onBack)
        }
    }
}

@Composable
private fun Bullet(title: String, body: String) {
    Column {
        Text(title, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        Text(body, color = Color.White.copy(alpha = 0.7f), fontSize = 13.sp)
    }
}

@Composable
fun GeneratingScreen(vm: TastecardViewModel) {
    val prog by vm.progress.collectAsState()
    val processed = prog.first
    val total = prog.second
    val fraction = if (total > 0) processed.toFloat() / total else 0f
    OnboardingBackground {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().padding(32.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(contentAlignment = Alignment.Center, modifier = Modifier.size(150.dp)) {
                @Suppress("DEPRECATION")
                CircularProgressIndicator(
                    progress = if (fraction <= 0f) 0.02f else fraction,
                    modifier = Modifier.size(150.dp),
                    color = Color(0xFFE2A9C0),
                    trackColor = Color.White.copy(alpha = 0.15f),
                    strokeWidth = 8.dp,
                )
                Text("${(fraction * 100).toInt()}%", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Black)
            }
            Spacer(Modifier.height(24.dp))
            Text("Reading your camera roll", color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(6.dp))
            Text(
                if (total > 0) "Analysing $processed of $total" else "Finding your photos…",
                color = Color.White.copy(alpha = 0.7f), fontSize = 14.sp,
            )
            Spacer(Modifier.height(4.dp))
            Mono("EVERYTHING STAYS ON YOUR DEVICE", Color.White.copy(alpha = 0.45f), 10, letter = 1.0)
            Spacer(Modifier.height(32.dp))
            SecondaryButton("Cancel", onClick = vm::cancel)
        }
    }
}

@Composable
fun WarmingUpScreen(
    reason: WarmingReason,
    scanned: Int,
    partialAccess: Boolean,
    onRetry: () -> Unit,
    onSelectMorePhotos: () -> Unit,
    onBack: () -> Unit,
) {
    val title = when (reason) {
        WarmingReason.NOT_ENOUGH_PHOTOS -> "Your collection is still warming up"
        WarmingReason.NOT_ENOUGH_EVIDENCE -> "Not quite enough to call it yet"
    }
    // With partial access the engine only sees the handful of photos the user picked, so the
    // fix is to share more — not to "take more photos". Lead with that when access is limited.
    val body = when {
        partialAccess ->
            "Tastecard can only see the photos you selected. Share more of your library, then try again."
        reason == WarmingReason.NOT_ENOUGH_PHOTOS ->
            "We need a few more photos before your Tastecard takes shape. Keep snapping — then come back."
        else ->
            "We couldn't find three clear themes yet. Add more shots of the things you love and try again."
    }
    OnboardingBackground {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().padding(28.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            CenteredMessage(
                emoji = "🌷",
                title = title,
                body = body,
                sub = if (scanned > 0) "Scanned $scanned photos" else null,
            )
            Spacer(Modifier.height(28.dp))
            if (partialAccess) {
                CTAButton("Select more photos", onClick = onSelectMorePhotos)
                Spacer(Modifier.height(8.dp))
                SecondaryButton("Try again", onClick = onRetry)
            } else {
                CTAButton("Try again", onClick = onRetry)
            }
            Spacer(Modifier.height(8.dp))
            SecondaryButton("Back", onClick = onBack)
        }
    }
}

@Composable
fun DeniedScreen(onOpenSettings: () -> Unit, onTryAgain: () -> Unit, onBack: () -> Unit) {
    OnboardingBackground {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().padding(28.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            CenteredMessage(
                emoji = "🔒",
                title = "Photo access is off",
                body = "Tastecard needs to read your photos on this device to build your card. Turn on photo access in Settings — your photos still never leave your device.",
            )
            Spacer(Modifier.height(28.dp))
            // Android only shows the system permission dialog the first time. Once denied, the
            // reliable path back is the app's Settings page; "Try again" still helps in the
            // case where the user merely dismissed the dialog without a permanent denial.
            CTAButton("Open settings", onClick = onOpenSettings)
            Spacer(Modifier.height(8.dp))
            SecondaryButton("Try again", onClick = onTryAgain)
            Spacer(Modifier.height(8.dp))
            SecondaryButton("Back", onClick = onBack)
        }
    }
}

@Composable
fun SetupScreen(message: String, onBack: () -> Unit) {
    OnboardingBackground {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().padding(28.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            CenteredMessage(emoji = "🛠️", title = "Analysis engine not installed", body = message)
            Spacer(Modifier.height(28.dp))
            SecondaryButton("Back to start", onClick = onBack)
        }
    }
}
