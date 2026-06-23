//
//  GenerationView.swift
//  Tastecard
//
//  §4.3 — chunked, cancellable generation with real progress ("analysing 1,240 of
//  3,000"). The UI stays responsive; the heavy work runs off the main actor (AppModel).
//

import SwiftUI

struct GenerationView: View {
    @EnvironmentObject private var model: AppModel

    private var progress: AnalysisProgress { model.progress ?? AnalysisProgress(processed: 0, total: 0) }

    var body: some View {
        ZStack {
            OnboardingBackground()
            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.onboardingInk.opacity(0.15), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: max(0.02, progress.fraction))
                        .stroke(
                            LinearGradient(colors: [Color(hex: 0xE2A9C0), Color(hex: 0x8387C3)],
                                           startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.25), value: progress.fraction)
                    VStack(spacing: 2) {
                        Text("\(Int(progress.fraction * 100))%")
                            .font(AppFont.mono(28, weight: .heavy))
                            .foregroundColor(.onboardingInk)
                    }
                }
                .frame(width: 150, height: 150)

                VStack(spacing: 6) {
                    Text("Reading your camera roll")
                        .font(AppFont.display(20, weight: .bold))
                        .foregroundColor(.onboardingInk)
                    if progress.total > 0 {
                        Text("Analysing \(progress.processed.formatted()) of \(progress.total.formatted())")
                            .font(AppFont.sans(14))
                            .foregroundColor(.onboardingInk.opacity(0.7))
                            .contentTransition(.numericText())
                    } else {
                        Text("Finding your photos…")
                            .font(AppFont.sans(14))
                            .foregroundColor(.onboardingInk.opacity(0.7))
                    }
                    Text("Everything stays on your device")
                        .font(AppFont.mono(10, weight: .medium))
                        .tracking(1)
                        .foregroundColor(.onboardingInk.opacity(0.45))
                        .padding(.top, 4)
                }

                Spacer()

                SecondaryButton(title: "Cancel") { model.cancelAnalysis() }
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 32)
        }
    }
}
