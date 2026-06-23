//
//  GreetingView.swift
//  Tastecard
//
//  §4.1 — one warm line, a blurred sample card teaser behind it, one primary CTA.
//

import SwiftUI

struct GreetingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            OnboardingBackground()

            // Teaser card, pushed back and blurred.
            SampleTeaserCard()
                .blur(radius: 9)
                .opacity(0.6)
                .scaleEffect(1.05)
                .offset(y: -30)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 16) {
                    Text("Rollcard")
                        .font(AppFont.mono(13, weight: .bold))
                        .tracking(4)
                        .foregroundColor(.onboardingInk.opacity(0.75))

                    Text("Find out what your\ncamera roll says about you")
                        .font(AppFont.display(30, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.onboardingInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Analysed entirely on your device. Nothing is ever uploaded.")
                        .font(AppFont.sans(14))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.onboardingInk.opacity(0.7))
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 28)

                CTAButton(title: "Create my Rollcard", systemImage: "sparkles") {
                    model.beginOnboarding()
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 40)
            }
            .padding(.bottom, 12)
        }
    }
}
