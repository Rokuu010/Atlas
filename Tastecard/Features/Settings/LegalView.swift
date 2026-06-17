//
//  LegalView.swift
//  Tastecard
//
//  Renders the bundled Privacy Policy / Terms (also hosted at the App Store Connect URLs,
//  see README). Loaded from the app bundle so they are always available offline.
//

import SwiftUI

enum LegalDocument: String, Identifiable {
    case privacy = "PrivacyPolicy"
    case terms = "Terms"
    var id: String { rawValue }
    var title: String { self == .privacy ? "Privacy Policy" : "Terms of Use" }
}

struct LegalView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss

    private var text: String {
        guard let url = Bundle.main.url(forResource: document.rawValue, withExtension: "md"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return "This document is unavailable."
        }
        return contents
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(AppFont.sans(14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .textSelection(.enabled)
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
