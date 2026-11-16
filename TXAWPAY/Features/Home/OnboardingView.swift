import SwiftUI
import SwiftData

/// First launch: welcome, name, and an honest choice of backup destination.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var backup: BackupManager
    @AppStorage(AppSettings.Keys.hasOnboarded) private var hasOnboarded = false
    @Query private var profiles: [UserSettings]
    @State private var page = 0
    @State private var name = ""
    @State private var pickingFolder = false
    @State private var folderError: String?

    var body: some View {
        ZStack {
            Image("HeroLandscape").resizable().scaledToFill().ignoresSafeArea()
                .overlay(LinearGradient(colors: [.clear, Theme.background.opacity(0.85), Theme.background],
                                        startPoint: .top, endPoint: .center).ignoresSafeArea())
                .accessibilityHidden(true)

            VStack {
                Spacer()
                TabView(selection: $page) {
                    welcome.tag(0)
                    nameStep.tag(1)
                    backupStep.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 470)
            }
        }
        .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                do { try backup.setFolder(url); finish() } catch { folderError = error.localizedDescription }
            case .failure(let error):
                folderError = error.localizedDescription
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: Theme.Spacing.l) {
            AppMark(size: 104)
            Text("TXAWPAY")
                .font(.system(.largeTitle, design: .serif).weight(.semibold))
                .tracking(6)
                .foregroundStyle(Theme.textPrimary)
            Text("Your world, in one place.")
                .font(Typo.bodySerif.italic())
                .foregroundStyle(Theme.textSecondary)
            Text("A private home for your days, journeys, ideas, learning and the people you love.")
                .multilineTextAlignment(.center)
                .font(Typo.callout)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, Theme.Spacing.xl)
            Button("Begin") { withAnimation { page = 1 } }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
    }

    private var nameStep: some View {
        VStack(spacing: Theme.Spacing.l) {
            Text("What should we call you?")
                .font(Typo.title)
                .foregroundStyle(Theme.textPrimary)
            TextField("Your name (optional)", text: $name)
                .textContentType(.givenName)
                .multilineTextAlignment(.center)
                .padding()
                .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.surface))
                .padding(.horizontal, Theme.Spacing.xxl)
            Text("Used only for your greeting. It never leaves your iPhone.")
                .font(Typo.caption).foregroundStyle(Theme.textTertiary)
            Button("Continue") {
                profiles.first?.displayName = name.trimmingCharacters(in: .whitespaces)
                try? context.save()
                withAnimation { page = 2 }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
    }

    private var backupStep: some View {
        VStack(spacing: Theme.Spacing.m) {
            Text("Keep your journal safe")
                .font(Typo.title)
                .foregroundStyle(Theme.textPrimary)
            Text("TXAWPAY saves every journal entry as a Markdown file in a TXAWPAY folder you can open in Files. If the app is ever deleted, your journal can be restored from it.")
                .font(Typo.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                Task {
                    backup.destination = .iCloudDrive
                    do {
                        _ = try await backup.resolveRoot()
                        await backup.changeDestination(to: .iCloudDrive)
                        finish()
                    } catch {
                        // Be honest: iCloud isn't usable in this build or account.
                        backup.destination = .onDevice
                        folderError = error.localizedDescription
                    }
                }
            } label: {
                Label("Use iCloud Drive", systemImage: "icloud")
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: true))
            Button { pickingFolder = true } label: {
                Label("Choose a folder in Files", systemImage: "folder")
            }
            .buttonStyle(SecondaryButtonStyle(fullWidth: true))
            Button("Decide later (saved on this iPhone only)") {
                backup.destination = .onDevice
                finish()
            }
            .font(Typo.caption)
            .foregroundStyle(Theme.textSecondary)
            if let folderError {
                Text(folderError).font(Typo.caption).foregroundStyle(Theme.danger)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private func finish() {
        hasOnboarded = true
        dismiss()
    }
}
