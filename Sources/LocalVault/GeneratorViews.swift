import SwiftUI
import VaultCore

/// Reusable generator controls. `onUse` is shown as a "Kullan" button when provided.
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
                    .buttonStyle(.borderless).help("Yeniden üret")
            }
            StrengthBar(password: password)
            HStack {
                Text("Uzunluk: \(options.length)").monospacedDigit().frame(width: 100, alignment: .leading)
                Slider(value: Binding(get: { Double(options.length) },
                                      set: { options.length = Int($0) }),
                       in: Double(GeneratorOptions.lengthRange.lowerBound)...Double(GeneratorOptions.lengthRange.upperBound),
                       step: 1)
            }
            Toggle("Büyük harf (A-Z)", isOn: $options.uppercase)
            Toggle("Küçük harf (a-z)", isOn: $options.lowercase)
            Toggle("Rakam (0-9)", isOn: $options.digits)
            Toggle("Sembol (!@#…)", isOn: $options.symbols)
            Toggle("Karışabilen karakterleri hariç tut (0 O l 1 I)", isOn: $options.excludeAmbiguous)
            HStack {
                Spacer()
                Button("Kopyala") { state.copy(password, label: "Parola") }
                if let onUse { Button("Kullan") { onUse(password) }.keyboardShortcut(.defaultAction) }
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
            Text("Parola üretici").font(.title2.bold())
            GeneratorPanel()
            HStack { Spacer(); Button("Kapat") { dismiss() }.keyboardShortcut(.cancelAction) }
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
            Text("Ana parolayı değiştir").font(.title2.bold())
            SecureField("Mevcut ana parola", text: $current)
            SecureField("Yeni ana parola (en az 8 karakter)", text: $new)
            SecureField("Yeni ana parola (tekrar)", text: $confirm)
            StrengthBar(password: new)
            if let error = state.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Vazgeç") { state.errorMessage = nil; dismiss() }.keyboardShortcut(.cancelAction)
                Button("Değiştir") {
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
