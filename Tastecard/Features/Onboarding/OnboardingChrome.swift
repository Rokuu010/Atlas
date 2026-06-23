//
//  OnboardingChrome.swift
//  Tastecard
//
//  Shared visual chrome for the non-card screens (greeting, priming, generation, edge
//  states). These pre-card screens use a warm palette — tan background, deep-plum ink.
//  The Rollcard itself and everything after it keep their own theme.
//

import SwiftUI

extension Color {
    /// Pre-card onboarding palette (greeting through generation). Nothing after the card uses these.
    static let onboardingBG = Color(hex: 0xF0C987)   // warm tan
    static let onboardingInk = Color(hex: 0x3B153A)  // deep plum
}

/// The warm onboarding/edge-screen background (pre-card only).
struct OnboardingBackground: View {
    var body: some View {
        Color.onboardingBG.ignoresSafeArea()
    }
}

/// Primary call-to-action: a solid plum pill with tan text, legible on the tan background.
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
            .foregroundColor(.onboardingBG)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.onboardingInk))
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
                .foregroundColor(.onboardingInk.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
}

/// A faux card used as the teaser behind the greeting (§4.1), styled for the warm background.
struct SampleTeaserCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle().fill(Color.onboardingInk.opacity(0.15)).frame(width: 28, height: 28)
                Spacer()
                Text("ROLLCARD").font(AppFont.mono(10, weight: .bold)).tracking(3)
                    .foregroundColor(.onboardingInk.opacity(0.8))
                Spacer()
                Circle().fill(Color.onboardingInk.opacity(0.15)).frame(width: 28, height: 28)
            }
            Text("Your Rollcard")
                .font(AppFont.display(26, weight: .bold)).foregroundColor(.onboardingInk)
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("2.3K").font(AppFont.mono(16, weight: .heavy)).foregroundColor(.onboardingInk)
                        Capsule().fill(Color.onboardingInk.opacity(0.25)).frame(width: 40, height: 5)
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
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.onboardingInk.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.onboardingInk.opacity(0.15)))
        )
    }
}
