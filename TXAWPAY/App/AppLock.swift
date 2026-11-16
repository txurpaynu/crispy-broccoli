import SwiftUI
import LocalAuthentication

/// Optional Face ID / Touch ID / passcode lock for the whole app.
///
/// Uses `.deviceOwnerAuthentication`, so if biometrics fail or aren't enrolled
/// the user can always fall back to the device passcode — they can never be
/// locked out of their own journal.
@MainActor
final class AppLock: ObservableObject {
    @Published private(set) var isLocked: Bool
    @Published var lastError: String?
    @AppStorage(AppSettings.Keys.appLockEnabled) var isEnabled = false
    @AppStorage(AppSettings.Keys.lockOnBackgroundDelay) var graceSeconds = 0

    private var backgroundedAt: Date?
    private var isAuthenticating = false

    init() {
        isLocked = UserDefaults.standard.bool(forKey: AppSettings.Keys.appLockEnabled)
    }

    var biometryName: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    var biometrySymbol: String {
        switch biometryName {
        case "Face ID": "faceid"
        case "Touch ID": "touchid"
        case "Optic ID": "opticid"
        default: "lock"
        }
    }

    var canUseLock: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func didEnterBackground() {
        backgroundedAt = Date()
    }

    func didBecomeActive() {
        guard isEnabled else { isLocked = false; return }
        if let backgroundedAt, Date().timeIntervalSince(backgroundedAt) >= Double(graceSeconds) {
            isLocked = true
        }
        backgroundedAt = nil
        if isLocked { Task { await unlock() } }
    }

    func unlock() async {
        guard isEnabled, isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Not now"
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your TXAWPAY space")
            if ok { isLocked = false; lastError = nil }
        } catch {
            lastError = (error as? LAError)?.code == .userCancel ? nil : error.localizedDescription
        }
    }

    /// Turning the lock on requires a successful authentication first.
    func setEnabled(_ enabled: Bool) async -> Bool {
        if !enabled { isEnabled = false; isLocked = false; return true }
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            lastError = err?.localizedDescription ?? "Set a device passcode to use the app lock."
            return false
        }
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Turn on the TXAWPAY lock")
            if ok { isEnabled = true }
            return ok
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}

struct LockView: View {
    @EnvironmentObject private var lock: AppLock

    var body: some View {
        ZStack {
            Image("HeroLandscape")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .blur(radius: 18)
                .overlay(Brand.deepTeal.opacity(0.55).ignoresSafeArea())
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.l) {
                Spacer()
                AppMark(size: 96)
                Text("TXAWPAY")
                    .font(.system(.title, design: .serif).weight(.semibold))
                    .tracking(4)
                    .foregroundStyle(Brand.warmIvory)
                Text("Your world, in one place.")
                    .font(Typo.callout)
                    .foregroundStyle(Brand.warmIvory.opacity(0.8))
                Spacer()
                if let error = lock.lastError {
                    Text(error)
                        .font(Typo.caption)
                        .foregroundStyle(Brand.warmIvory.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label("Unlock with \(lock.biometryName)", systemImage: lock.biometrySymbol)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 48)
            }
        }
        .task { await lock.unlock() }
    }
}

/// Shown while the app is inactive (app switcher) when the lock is enabled.
struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Theme.backgroundDeep.ignoresSafeArea()
            AppMark(size: 84)
        }
    }
}
