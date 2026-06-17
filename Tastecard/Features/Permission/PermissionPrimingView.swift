//
//  PermissionPrimingView.swift
//  Tastecard
//
//  §4.2 — honest pre-prompt shown BEFORE the iOS Photos dialog. Explains on-device
//  analysis, no uploads, and that the user may grant all or only selected photos. This
//  improves grant rates and is the GDPR-aligned pattern (§8).
//

import SwiftUI

struct PermissionPrimingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var requesting = false

    private let points: [(String, String, String)] = [
        ("lock.shield", "Stays on your device", "Your photos are analysed locally. Nothing is uploaded — ever."),
        ("doc.text.magnifyingglass", "No documents or sensitive content sent", "We never transmit your photos, screenshots, or their contents anywhere."),
        ("checkmark.circle", "All or only selected photos", "On the next screen you can grant access to your whole library or just a few photos."),
    ]

    var body: some View {
        ZStack {
            OnboardingBackground()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 22) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.white)

                    Text("Before we look at your photos")
                        .font(AppFont.display(24, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(points, id: \.0) { point in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: point.0)
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundColor(.white)
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(point.1)
                                        .font(AppFont.sans(15, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(point.2)
                                        .font(AppFont.sans(13))
                                        .foregroundColor(.white.opacity(0.7))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(20)
                    .glassCard(cornerRadius: 28, fill: .white.opacity(0.06), border: .white.opacity(0.12))
                }
                .padding(.horizontal, 28)

                Spacer()

                VStack(spacing: 14) {
                    CTAButton(title: requesting ? "Requesting…" : "Continue", systemImage: "arrow.right") {
                        guard !requesting else { return }
                        requesting = true
                        Task { await model.grantAccessAndAnalyse(); requesting = false }
                    }
                    SecondaryButton(title: "Not now") { model.phase = .greeting }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
            }
        }
    }
}
