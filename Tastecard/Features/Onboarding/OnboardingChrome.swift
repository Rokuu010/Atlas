//
//  OnboardingChrome.swift
//  Tastecard
//
//  Shared visual chrome for the non-card screens (greeting, priming, generation, edge
//  states). Uses the design system's glass + typography so onboarding feels of-a-piece
//  with the card.
//

import SwiftUI

/// A calm, branded background for onboarding/edge screens.
struct OnboardingBackground: View {
    var body: some View {
        ZStack {
            Color(hex: 0x3F2A52)
            RadialGradient(
                colors: [Color(hex: 0x75619D).opacity(0.55), .clear],
                center: .top, startRadius: 20, endRadius: 520
            )
            RadialGradient(
                colors: [Color(hex: 0xA24C61).opacity(0.30), .clear],
                center: .bottomTrailing, startRadius: 10, endRadius: 460
            )
        }
        .ignoresSafeArea()
    }
}

/// Primary glass call-to-action button matching the card's "Share Tastecard" style.
struct CTAButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title.uppercased())
            }
            .font(AppFont.sans(13, weight: .black))
            .tracking(2)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassPill(cornerRadius: 18, fill: .white.opacity(0.18), border: .white.opacity(0.35))
        }
        .buttonStyle(.plain)
    }
}

/// Secondary, low-emphasis text button.
struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            Text(title)
                .font(AppFont.sans(13, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
}

/// A blurred faux card used as the teaser behind the greeting (§4.1).
struct SampleTeaserCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle().fill(.white.opacity(0.18)).frame(width: 28, height: 28)
                Spacer()
                Text("TASTECARD").font(AppFont.mono(10, weight: .bold)).tracking(3)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Circle().fill(.white.opacity(0.18)).frame(width: 28, height: 28)
            }
            Text("Your Tastecard")
                .font(AppFont.display(26, weight: .bold)).foregroundColor(.white)
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("2.3K").font(AppFont.mono(16, weight: .heavy)).foregroundColor(.white)
                        Capsule().fill(.white.opacity(0.3)).frame(width: 40, height: 5)
                    }
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0x8387C3), Color(hex: 0xA24C61)],
                                             startPoint: .top, endPoint: .bottom))
                        .aspectRatio(3.0/4.0, contentMode: .fit)
                        .opacity(i < 2 ? 1 : 0.4)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: 340)
        .glassCard(fill: .white.opacity(0.06), border: .white.opacity(0.12))
    }
}
