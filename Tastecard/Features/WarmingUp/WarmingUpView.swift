//
//  WarmingUpView.swift
//  Tastecard
//
//  §4.3 — the "still warming up" state shown when fewer than 3 themes clear the bar, or
//  the library is below the global minimum. We never pad a thin card with fragile data.
//

import SwiftUI

struct WarmingUpView: View {
    @EnvironmentObject private var model: AppModel
    let reason: WarmingReason
    let photosScanned: Int

    private var headline: String {
        switch reason {
        case .notEnoughPhotos: return "Your collection is still warming up"
        case .notEnoughEvidence: return "Not quite enough to call it yet"
        }
    }

    private var body2: String {
        switch reason {
        case .notEnoughPhotos:
            return "We need a few more photos before your Tastecard takes shape. Keep snapping — then come back."
        case .notEnoughEvidence:
            return "Your photos are wonderfully varied! We couldn't find three clear themes yet. Add more shots of the things you love and try again."
        }
    }

    var body: some View {
        ZStack {
            OnboardingBackground()
            VStack(spacing: 22) {
                Spacer()
                Image(systemName: "camera.macro")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(.white)
                Text(headline)
                    .font(AppFont.display(24, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                Text(body2)
                    .font(AppFont.sans(15))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.72))
                    .padding(.horizontal, 28)
                if photosScanned > 0 {
                    Text("Scanned \(photosScanned.formatted()) photos")
                        .font(AppFont.mono(11))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
                VStack(spacing: 14) {
                    CTAButton(title: "Try again", systemImage: "arrow.clockwise") {
                        Task { await model.regenerate() }
                    }
                    if model.photoService.isLimited {
                        SecondaryButton(title: "Select more photos") { model.presentLimitedPicker() }
                    }
                    SecondaryButton(title: "Back") { model.phase = .greeting }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
            }
        }
    }
}
