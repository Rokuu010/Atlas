//
//  SetupRequiredView.swift
//  Tastecard
//
//  Shown only in a development build where the on-device model / precomputed text
//  vectors are not yet bundled, or the dataset failed validation. Keeps the app from
//  crashing and tells the developer exactly what to do (see README). End users never see
//  this in a correctly built release.
//

import SwiftUI

struct SetupRequiredView: View {
    @EnvironmentObject private var model: AppModel
    let message: String

    var body: some View {
        ZStack {
            OnboardingBackground()
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.onboardingInk)
                Text("Analysis engine not installed")
                    .font(AppFont.display(22, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.onboardingInk)
                Text(message)
                    .font(AppFont.sans(13))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.onboardingInk.opacity(0.7))
                    .padding(.horizontal, 24)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                SecondaryButton(title: "Back to start") { model.phase = .greeting }
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 28)
        }
    }
}
