import SwiftUI
import VaultCore

struct VaultView: View {
    @EnvironmentObject var state: AppState
    @State private var selection: Entry.ID?
    @State private var search = ""
    @State private var editing: Entry?
    @State private var showGenerator = false
    @State private var showChangePassword = false
    @State private var pendingDelete: Entry?

    private var filtered: [Entry] { state.entries.filter { $0.matches(search) } }

    var body: some View {
        NavigationSplitView {
            List(filtered, selection: $selection) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title.isEmpty ? "(başlıksız)" : entry.title).font(.headline)
                    if !entry.username.isEmpty {
                        Text(entry.username).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .tag(entry.id)
                .contextMenu {
                    Button("Kullanıcı adını kopyala") { state.copy(entry.username, label: "Kullanıcı adı") }
                    Button("Parolayı kopyala") { state.copy(entry.password, label: "Parola") }
                    Divider()
                    Button("Düzenle") { editing = entry }
                    Button("Sil", role: .destructive) { pendingDelete = entry }
                }
            }
            .searchable(text: $search, placement: .sidebar, prompt: "Ara")
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView(search.isEmpty ? "Henüz kayıt yok" : "Sonuç yok",
                                           systemImage: search.isEmpty ? "key" : "magnifyingglass",
                                           description: Text(search.isEmpty ? "＋ ile ilk parolanızı ekleyin." : ""))
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let id = selection, let entry = state.entries.first(where: { $0.id == id }) {
                EntryDetailView(entry: entry, onEdit: { editing = entry }, onDelete: { pendingDelete = entry })
            } else {
                ContentUnavailableView("Bir kayıt seçin", systemImage: "lock.open")
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button { editing = Entry() } label: { Label("Yeni kayıt", systemImage: "plus") }
                    .keyboardShortcut("n", modifiers: .command)
                Button { showGenerator = true } label: { Label("Parola üretici", systemImage: "wand.and.stars") }
                    .keyboardShortcut("g", modifiers: .command)
                Menu {
                    Button("Ana parolayı değiştir…") { showChangePassword = true }
                    Button("Şifreli yedeği dışa aktar…") { state.exportBackup() }
                } label: { Label("Ayarlar", systemImage: "gearshape") }
                Button { state.lock() } label: { Label("Kilitle", systemImage: "lock") }
            }
        }
        .sheet(item: $editing) { entry in
            EntryEditorView(entry: entry) { saved in
                state.upsert(saved)
                selection = saved.id
            }
        }
        .sheet(isPresented: $showGenerator) {
            GeneratorSheet()
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordView()
        }
        .confirmationDialog("“\(pendingDelete?.title ?? "")” silinsin mi?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Sil", role: .destructive) {
                if let e = pendingDelete {
                    state.delete(e.id)
                    if selection == e.id { selection = nil }
                }
                pendingDelete = nil
            }
        } message: { Text("Bu işlem geri alınamaz.") }
        .alert("Hata", isPresented: Binding(get: { state.errorMessage != nil },
                                            set: { if !$0 { state.errorMessage = nil } })) {
            Button("Tamam") {}
        } message: { Text(state.errorMessage ?? "") }
    }
}

struct EntryDetailView: View {
    @EnvironmentObject var state: AppState
    let entry: Entry
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var reveal = false

    var body: some View {
        Form {
            Section {
                row("Kullanıcı adı", entry.username) {
                    state.copy(entry.username, label: "Kullanıcı adı")
                }
                LabeledContent("Parola") {
                    HStack {
                        Text(reveal ? entry.password : String(repeating: "•", count: min(entry.password.count, 16)))
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                        Spacer()
                        Button { reveal.toggle() } label: {
                            Image(systemName: reveal ? "eye.slash" : "eye")
                        }.help(reveal ? "Gizle" : "Göster")
                        Button { state.copy(entry.password, label: "Parola") } label: {
                            Image(systemName: "doc.on.doc")
                        }.help("Kopyala")
                    }.buttonStyle(.borderless)
                }
                StrengthBar(password: entry.password)
                if !entry.url.isEmpty {
                    LabeledContent("URL") {
                        if let url = URL(string: entry.url.contains("://") ? entry.url : "https://\(entry.url)") {
                            Link(entry.url, destination: url)
                        } else {
                            Text(entry.url)
                        }
                    }
                }
            }
            if !entry.notes.isEmpty {
                Section("Notlar") { Text(entry.notes).textSelection(.enabled) }
            }
            Section {
                LabeledContent("Oluşturuldu", value: entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Güncellendi", value: entry.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .formStyle(.grouped)
        .navigationTitle(entry.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Düzenle", action: onEdit)
                Button(role: .destructive, action: onDelete) { Label("Sil", systemImage: "trash") }
            }
        }
        .onChange(of: entry.id) { reveal = false }
    }

    private func row(_ label: String, _ value: String, copy: @escaping () -> Void) -> some View {
        LabeledContent(label) {
            HStack {
                Text(value).textSelection(.enabled)
                Spacer()
                if !value.isEmpty {
                    Button(action: copy) { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.borderless).help("Kopyala")
                }
            }
        }
    }
}

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var entry: Entry
    let onSave: (Entry) -> Void
    @State private var reveal = false
    @State private var showGenerator = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Başlık", text: $entry.title)
                TextField("Kullanıcı adı / e-posta", text: $entry.username)
                HStack {
                    Group {
                        if reveal { TextField("Parola", text: $entry.password) }
                        else { SecureField("Parola", text: $entry.password) }
                    }.font(.body.monospaced())
                    Button { reveal.toggle() } label: { Image(systemName: reveal ? "eye.slash" : "eye") }
                        .buttonStyle(.borderless)
                    Button { showGenerator.toggle() } label: { Image(systemName: "wand.and.stars") }
                        .buttonStyle(.borderless).help("Parola üret")
                        .popover(isPresented: $showGenerator) {
                            GeneratorPanel { entry.password = $0; reveal = true; showGenerator = false }
                                .padding().frame(width: 380)
                        }
                }
                StrengthBar(password: entry.password)
                TextField("URL", text: $entry.url)
                TextField("Notlar", text: $entry.notes, axis: .vertical).lineLimit(3...8)
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Vazgeç", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Kaydet") { onSave(entry); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(entry.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }.padding()
        }
        .frame(width: 480)
    }
}
