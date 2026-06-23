package io.tastecard.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import io.tastecard.model.RarityTier

/** Pre-card onboarding palette (greeting through generation); the card keeps its own theme. */
val OnboardingBG = Color(0xFFF0C987)   // warm tan
val OnboardingInk = Color(0xFF3B153A)  // deep plum

/** Translucent "glass" surface (no live blur — broad device compatibility). */
fun Modifier.glass(fill: Color, border: Color, radius: Dp): Modifier =
    this.clip(RoundedCornerShape(radius))
        .background(fill)
        .border(1.dp, border, RoundedCornerShape(radius))

@Composable
fun CTAButton(text: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .glass(OnboardingInk, OnboardingInk, 18.dp)
            .clickable { onClick() }
            .padding(vertical = 16.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text.uppercase(),
            color = OnboardingBG,
            fontWeight = FontWeight.Black,
            fontSize = 13.sp,
            letterSpacing = 2.sp,
        )
    }
}

@Composable
fun SecondaryButton(text: String, onClick: () -> Unit) {
    Text(
        text,
        color = OnboardingInk.copy(alpha = 0.7f),
        fontWeight = FontWeight.SemiBold,
        fontSize = 13.sp,
        modifier = Modifier.clickable { onClick() }.padding(8.dp),
    )
}

@Composable
fun RarityBadge(tier: RarityTier, fontSize: Int = 12) {
    Text(
        tier.displayName.uppercase(),
        style = TextStyle(
            brush = RarityGradients.brush(tier),
            fontWeight = FontWeight.Black,
            fontSize = fontSize.sp,
            letterSpacing = 1.sp,
        ),
    )
}

@Composable
fun Mono(text: String, color: Color, size: Int, weight: FontWeight = FontWeight.Normal, letter: Double = 0.0) {
    Text(text, color = color, fontFamily = FontFamily.Monospace, fontSize = size.sp, fontWeight = weight, letterSpacing = letter.sp)
}

/** Loads a content:// photo, or shows a gradient placeholder. */
@Composable
fun AssetImage(uri: String?, modifier: Modifier = Modifier) {
    if (uri != null) {
        AsyncImage(
            model = uri,
            contentDescription = null,
            modifier = modifier,
            contentScale = androidx.compose.ui.layout.ContentScale.Crop,
        )
    } else {
        Box(
            modifier.background(
                Brush.linearGradient(listOf(Color(0xFF3A3E6C), Color(0xFF75619D), Color(0xFF8A8CAC)))
            )
        )
    }
}

@Composable
fun OnboardingBackground(content: @Composable () -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .background(
                OnboardingBG
            )
    ) { content() }
}

@Composable
fun CenteredMessage(
    emoji: String,
    title: String,
    body: String,
    sub: String? = null,
    modifier: Modifier = Modifier,
) {
    androidx.compose.foundation.layout.Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(emoji, fontSize = 40.sp)
        androidx.compose.foundation.layout.Spacer(Modifier.padding(8.dp))
        Text(title, color = OnboardingInk, fontSize = 24.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        androidx.compose.foundation.layout.Spacer(Modifier.padding(6.dp))
        Text(body, color = OnboardingInk.copy(alpha = 0.72f), fontSize = 15.sp, textAlign = TextAlign.Center)
        if (sub != null) {
            androidx.compose.foundation.layout.Spacer(Modifier.padding(6.dp))
            Mono(sub, OnboardingInk.copy(alpha = 0.45f), 11)
        }
    }
}
