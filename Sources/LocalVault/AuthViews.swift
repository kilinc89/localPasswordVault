import SwiftUI
import VaultCore

struct SetupView: View {
    @EnvironmentObject var state: AppState
    @State private var password = ""
    @State private var confirm = ""

    var body: some View {
        AuthCard(icon: "lock.shield", title: "LocalVault'a hoş geldiniz",
                 subtitle: "Kasanızı korumak için bir ana parola belirleyin. Bu parola kurtarılamaz — unutmayın.") {
            SecureField("Ana parola (en az 8 karakter)", text: $password)
            SecureField("Ana parolayı tekrar girin", text: $confirm)
                .onSubmit(create)
            StrengthBar(password: password)
            Button("Kasa oluştur", action: create)
                .keyboardShortcut(.defaultAction)
                .disabled(password.count < VaultStore.minimumPasswordLength || confirm.isEmpty)
        }
    }

    private func create() { state.createVault(password: password, confirm: confirm) }
}

struct UnlockView: View {
    @EnvironmentObject var state: AppState
    @State private var password = ""
    @State private var busy = false
    @FocusState private var focused: Bool

    var body: some View {
        AuthCard(icon: "lock.fill", title: "Kasa kilitli", subtitle: "Devam etmek için ana parolanızı girin.") {
            SecureField("Ana parola", text: $password)
                .focused($focused)
                .onSubmit(unlock)
            Button(busy ? "Açılıyor…" : "Kilidi aç", action: unlock)
                .keyboardShortcut(.defaultAction)
                .disabled(password.isEmpty || busy)
        }
        .onAppear { focused = true }
    }

    private func unlock() {
        busy = true
        // Let the button redraw before the (deliberately slow) key derivation runs.
        DispatchQueue.main.async {
            state.unlock(password: password)
            password = ""
            busy = false
        }
    }
}

struct AuthCard<Content: View>: View {
    @EnvironmentObject var state: AppState
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 44)).foregroundStyle(.tint)
            Text(title).font(.title2.bold())
            Text(subtitle).foregroundStyle(.secondary).multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 10) { content }
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
            if let error = state.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
            }
        }
        .frame(maxWidth: 360)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StrengthBar: View {
    let password: String

    var body: some View {
        let strength = PasswordStrength.evaluate(password)
        HStack(spacing: 8) {
            ProgressView(value: password.isEmpty ? 0 : Double(strength.rawValue + 1), total: 4)
                .tint(color(strength))
            Text(password.isEmpty ? "—" : "\(strength.label) · \(Int(PasswordStrength.entropy(password))) bit")
                .font(.caption).foregroundStyle(.secondary)
                .frame(width: 120, alignment: .trailing)
        }
    }

    private func color(_ s: Strength) -> Color {
        switch s {
        case .weak: return .red
        case .fair: return .orange
        case .strong: return .green
        case .veryStrong: return .blue
        }
    }
}
