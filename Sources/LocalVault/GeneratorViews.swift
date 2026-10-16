import SwiftUI
import VaultCore

/// Reusable generator controls. `onUse` is shown as a "Use" button when provided.
struct GeneratorPanel: View {
    @EnvironmentObject var state: AppState
    @State private var options = GeneratorOptions()
    @State private var password = ""
    var onUse: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(password)
                    .font(.system(.title3, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { regenerate() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless).help(L("Yeniden üret", "Regenerate"))
            }
            StrengthBar(password: password)
            HStack {
                Text(L("Uzunluk: \(options.length)", "Length: \(options.length)")).monospacedDigit().frame(width: 100, alignment: .leading)
                Slider(value: Binding(get: { Double(options.length) },
                                      set: { options.length = Int($0) }),
                       in: Double(GeneratorOptions.lengthRange.lowerBound)...Double(GeneratorOptions.lengthRange.upperBound),
                       step: 1)
            }
            Toggle(L("Büyük harf (A-Z)", "Uppercase (A-Z)"), isOn: $options.uppercase)
            Toggle(L("Küçük harf (a-z)", "Lowercase (a-z)"), isOn: $options.lowercase)
            Toggle(L("Rakam (0-9)", "Digits (0-9)"), isOn: $options.digits)
            Toggle(L("Sembol (!@#…)", "Symbols (!@#…)"), isOn: $options.symbols)
            Toggle(L("Karışabilen karakterleri hariç tut (0 O l 1 I)", "Exclude ambiguous characters (0 O l 1 I)"), isOn: $options.excludeAmbiguous)
            HStack {
                Spacer()
                Button(L("Kopyala", "Copy")) { state.copy(password, label: L("Parola", "Password")) }
                if let onUse { Button(L("Kullan", "Use")) { onUse(password) }.keyboardShortcut(.defaultAction) }
            }
        }
        .onAppear(perform: regenerate)
        .onChange(of: options) { regenerate() }
    }

    private func regenerate() { password = PasswordGenerator.generate(options) }
}

struct GeneratorSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("Parola üretici", "Password generator")).font(.title2.bold())
            GeneratorPanel()
            HStack { Spacer(); Button(L("Kapat", "Close")) { dismiss() }.keyboardShortcut(.cancelAction) }
        }
        .padding(24)
        .frame(width: 460)
    }
}

struct ChangePasswordView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var new = ""
    @State private var confirm = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Ana parolayı değiştir", "Change master password")).font(.title2.bold())
            SecureField(L("Mevcut ana parola", "Current master password"), text: $current)
            SecureField(L("Yeni ana parola (en az 8 karakter)", "New master password (at least 8 characters)"), text: $new)
            SecureField(L("Yeni ana parola (tekrar)", "New master password (again)"), text: $confirm)
            StrengthBar(password: new)
            if let error = state.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button(L("Vazgeç", "Cancel")) { state.errorMessage = nil; dismiss() }.keyboardShortcut(.cancelAction)
                Button(L("Değiştir", "Change")) {
                    if state.changePassword(current: current, new: new, confirm: confirm) { dismiss() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(current.isEmpty || new.count < VaultStore.minimumPasswordLength)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(24)
        .frame(width: 420)
    }
}
