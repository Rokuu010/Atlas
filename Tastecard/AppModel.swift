//
//  AppModel.swift
//  Tastecard
//
//  Root orchestrator and flow router (§4). Owns the current phase, the Photos service,
//  the persisted card, and the analysis lifecycle (start / progress / cancel). Builds
//  the engine lazily and degrades to a clear setup state if the on-device model/text
//  vectors are not yet bundled (see README).
//

import SwiftUI
import UIKit
import Photos

enum AppPhase: Equatable {
    case greeting
    case priming
    case generating
    case card
    case warmingUp(WarmingReason, photosScanned: Int)
    case permissionDenied
    case setupRequired(String)    // engine model/vectors missing or dataset invalid
}

@MainActor
final class AppModel: ObservableObject {

    @Published var phase: AppPhase = .greeting
    @Published var progress: AnalysisProgress?
    @Published private(set) var cardViewModel: CardViewModel?

    let photoService = PhotoLibraryService()
    private let store = TastecardStore()
    private var categories: [Category] = []
    private var analysisTask: Task<Void, Never>?

    init() {
        bootstrap()
    }

    private func bootstrap() {
        do {
            categories = try CategoryStore.loadBundled()
        } catch {
            phase = .setupRequired(error.localizedDescription)
            return
        }
        if let saved = store.load() {
            cardViewModel = CardViewModel(card: saved, store: store)
            phase = .card
        } else {
            phase = .greeting
        }
    }

    // MARK: - Flow

    func beginOnboarding() {
        Haptics.tap()
        phase = .priming
    }

    /// Called from the priming screen's CTA: trigger the native prompt, then analyse.
    func grantAccessAndAnalyse() async {
        let status = await photoService.requestAccess()
        switch status {
        case .authorized, .limited:
            await startAnalysis()
        case .denied, .restricted:
            Haptics.warning()
            phase = .permissionDenied
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func startAnalysis() async {
        guard photoService.isAuthorized else { phase = .permissionDenied; return }
        guard let engine = makeEngine() else {
            phase = .setupRequired(
                "The on-device analysis model isn't installed in this build yet. "
                + "Run scripts/convert_siglip_coreml.py and scripts/precompute_text_embeddings.py, "
                + "add the outputs to the app target, and rebuild."
            )
            return
        }

        progress = AnalysisProgress(processed: 0, total: 0)
        phase = .generating

        analysisTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            do {
                let result = try await engine.run { p in
                    Task { @MainActor in self.progress = p }
                }
                await MainActor.run { self.finish(result) }
            } catch is CancellationError {
                await MainActor.run { self.phase = .greeting }
            } catch {
                await MainActor.run { self.phase = .setupRequired(error.localizedDescription) }
            }
        }
    }

    func cancelAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
        Haptics.tap()
        phase = cardViewModel == nil ? .greeting : .card
    }

    func regenerate() async {
        await startAnalysis()
    }

    private func finish(_ result: EngineResult) {
        switch result {
        case .card(let card):
            store.save(card)
            cardViewModel = CardViewModel(card: card, store: store)
            Haptics.success()
            phase = .card
        case .warmingUp(let reason, let scanned):
            phase = .warmingUp(reason, photosScanned: scanned)
        }
    }

    private func makeEngine() -> AnalysisEngine? {
        do {
            let embedder = try CoreMLImageEmbedder()
            let textStore = try TextEmbeddingStore.loadBundled()
            guard embedder.dimension == textStore.dimension else { return nil }
            let cache = EmbeddingCache(dimension: embedder.dimension)
            return AnalysisEngine(
                loader: photoService.loader,
                embedder: embedder,
                textStore: textStore,
                categories: categories,
                cache: cache
            )
        } catch {
            return nil
        }
    }

    // MARK: - Data deletion (§8)

    func deleteAllData() async {
        cancelAnalysis()
        await DataDeletion.deleteEverything(store: store)
        cardViewModel = nil
        progress = nil
        Haptics.success()
        phase = .greeting
    }

    // MARK: - Limited library

    func presentLimitedPicker() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController else { return }
        photoService.presentLimitedLibraryPicker(from: root)
    }
}

extension UIWindowScene {
    var keyWindow: UIWindow? { windows.first(where: { $0.isKeyWindow }) ?? windows.first }
}
