//
//  SettingsView.swift
//  Tastecard
//
//  Card settings: edit the (sanitised) display name, manage the limited library, reset
//  the custom background, regenerate, view the privacy policy / terms, and the one-tap
//  "Delete my Tastecard data" (§8 right to erasure / §10 5.1.1(v)).
//

import SwiftUI
import PhotosUI

struct SettingsView: View {
    @ObservedObject var vm: CardViewModel
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var aboutText: String = ""
    @State private var profilePickerItem: PhotosPickerItem?
    @State private var showDeleteConfirm = false
    @State private var showAppearance = false
    @State private var legal: LegalDocument?

    var body: some View {
        NavigationStack {
            Form {
                Section("Your name") {
                    TextField("Your name", text: $name)
                        .font(AppFont.sans(16))
                        .submitLabel(.done)
                        .onSubmit { commitName() }
                    Text("Shown as “\(Tastecard.title(forName: name))”. Max \(InputSanitizer.maxDisplayNameLength) characters.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Profile photo") {
                    HStack(spacing: 12) {
                        ProfileAvatar(image: vm.profileImage, ink: .primary, size: 44)
                        PhotosPicker(selection: $profilePickerItem, matching: .images, photoLibrary: .shared()) {
                            Text(vm.profileImage == nil ? "Choose photo" : "Change photo")
                        }
                        Spacer()
                        if vm.profileImage != nil {
                            Button("Remove", role: .destructive) { vm.clearProfileImage() }
                        }
                    }
                }

                Section("About me") {
                    TextField("A line about you", text: $aboutText, axis: .vertical)
                        .font(AppFont.sans(16))
                        .lineLimit(1...4)
                        .onChange(of: aboutText) { _ in commitAbout() }
                    Text("Up to \(InputSanitizer.maxAboutMeLength) characters. Shown on your card before your themes.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Your Tastecard") {
                    labeledRow("Code", vm.card.serialDisplay)
                    labeledRow("Photos analysed", vm.card.photosAnalysed.formatted())
                    labeledRow("Emerging themes", "\(vm.card.emergentThemeCount)")
                    labeledRow("Places", "\(vm.card.placesCount)")
                    labeledRow("Rarity", vm.card.cardRarity.displayName.capitalized)
                }

                Section("Photos & appearance") {
                    Button("Appearance (colour, background, opacity)") { showAppearance = true }
                    if model.photoService.isLimited {
                        Button("Select more photos") { model.presentLimitedPicker() }
                    }
                    if vm.customBackground != nil {
                        Button("Remove custom background", role: .destructive) { vm.clearCustomBackground() }
                    }
                    Button("Re-analyse my camera roll") {
                        dismiss()
                        Task { await model.regenerate() }
                    }
                }

                Section("Privacy") {
                    Button("Privacy Policy") { legal = .privacy }
                    Button("Terms of Use") { legal = .terms }
                    Text("Tastecard analyses your photos on-device. Nothing is uploaded, stored off-device, or shared with third parties. There are no ads or trackers.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section {
                    Button("Delete my Tastecard data", role: .destructive) { showDeleteConfirm = true }
                } footer: {
                    Text("Removes your saved card, the on-device analysis cache, and any custom background from this device. This cannot be undone.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { commitName(); dismiss() }
                }
            }
            .onAppear {
                name = vm.card.displayName
                aboutText = vm.card.aboutMe ?? ""
            }
            .onDisappear { commitName(); commitAbout() }
            .onChange(of: profilePickerItem) { item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        vm.setProfileImage(data: data)
                    }
                    profilePickerItem = nil
                }
            }
            .alert("Delete all data?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    dismiss()
                    Task { await model.deleteAllData() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes your card and on-device cache.")
            }
            .sheet(item: $legal) { doc in LegalView(document: doc) }
            .sheet(isPresented: $showAppearance) { AppearanceSheet(vm: vm) }
        }
    }

    private func commitName() {
        vm.rename(name)
        name = vm.card.displayName
    }

    private func commitAbout() {
        vm.setAboutMe(aboutText)
    }

    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
