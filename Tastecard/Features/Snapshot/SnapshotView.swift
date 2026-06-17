//
//  SnapshotView.swift
//  Tastecard
//
//  The share sheet (§4.6 / §7). Pre-warms the (max 4) hero images into UIImages so the
//  ImageRenderer export is synchronous and pixel-identical, shows a true-to-output
//  preview, and shares the real PNG via the native sheet. No "copy link" anywhere (§11).
//

import SwiftUI
import UIKit

struct SnapshotView: View {
    let card: Tastecard
    let theme: AppTheme
    let customBackground: UIImage?
    let isBgDark: Bool
    let selectedThemeId: String?

    @Environment(\.dismiss) private var dismiss
    @State private var heroImages: [String: UIImage] = [:]
    @State private var isReady = false
    @State private var isSharing = false
    @State private var errorMessage: String?

    private var snapshot: SnapshotCardView {
        SnapshotCardView(card: card, theme: theme, customBackground: customBackground,
                         isBgDark: isBgDark, selectedThemeId: selectedThemeId, heroImages: heroImages)
    }

    var body: some View {
        ZStack {
            Color(hex: 0x0B1220).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                preview
                footerButtons
            }
        }
        .presentationDetents([.large])
        .task { await prewarm() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "fork.knife").foregroundColor(Color(hex: 0xF59E0B)).font(.system(size: 13))
            Text("SHARE YOUR TASTE")
                .font(AppFont.mono(11, weight: .bold)).tracking(2)
                .foregroundColor(.white.opacity(0.85))
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32).background(Circle().fill(.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.06)).frame(height: 1) }
    }

    private var preview: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / SnapshotCardView.baseWidth,
                            geo.size.height / (SnapshotCardView.baseWidth * 16/9))
            ZStack {
                if isReady {
                    snapshot
                        .scaleEffect(scale)
                        .frame(width: SnapshotCardView.baseWidth * scale,
                               height: SnapshotCardView.baseWidth * 16/9 * scale)
                        .clipShape(RoundedRectangle(cornerRadius: 24 * scale, style: .continuous))
                        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .padding(20)
    }

    private var footerButtons: some View {
        VStack(spacing: 10) {
            if let errorMessage {
                Text(errorMessage).font(AppFont.sans(12)).foregroundColor(Color(hex: 0xFDA4AF))
            }
            Button {
                share()
            } label: {
                HStack(spacing: 8) {
                    if isSharing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text(isSharing ? "Preparing…" : "Share Tastecard")
                }
                .font(AppFont.sans(13, weight: .black)).tracking(1)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0xEC4899), Color(hex: 0xE11D48)],
                                             startPoint: .leading, endPoint: .trailing))
                )
            }
            .buttonStyle(.plain)
            .disabled(!isReady || isSharing)
            .opacity(isReady ? 1 : 0.5)

            Text("Shares a high-resolution image. Nothing is uploaded.")
                .font(AppFont.mono(9)).foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 20).padding(.bottom, 24).padding(.top, 8)
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.06)).frame(height: 1) }
    }

    // MARK: - Actions

    private func prewarm() async {
        let loader = PhotoAssetLoader()
        var dict: [String: UIImage] = [:]
        for theme in card.themes.prefix(4) {
            guard let id = theme.heroPhotoLocalId else { continue }
            if let img = await loader.requestImage(forIdentifier: id, targetSide: 900) {
                dict[id] = img
            }
        }
        heroImages = dict
        isReady = true
    }

    private func share() {
        guard isReady, !isSharing else { return }
        isSharing = true
        errorMessage = nil
        // Render on the main actor; it's fast for a single 9:16 surface.
        if let url = SnapshotRenderer.renderToTempFile(snapshot, displayName: card.displayName) {
            Haptics.success()
            ShareService.present(items: [url]) { isSharing = false }
        } else {
            Haptics.warning()
            errorMessage = "Couldn't create the image. Please try again."
            isSharing = false
        }
    }
}
