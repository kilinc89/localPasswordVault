import SwiftUI
import VaultCore

struct VaultView: View {
    @EnvironmentObject var state: AppState
    @State private var selection: Entry.ID?
    @State private var search = ""
    @State private var editing: Entry?
    @State private var showGenerator = false
    @State private var showChangePassword = false
    @State private var showImport = false
    @State private var pendingDelete: Entry?

    private var filtered: [Entry] { state.entries.filter { $0.matches(search) } }

    var body: some View {
        NavigationSplitView {
            List(filtered, selection: $selection) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title.isEmpty ? L("(başlıksız)", "(untitled)") : entry.title).font(.headline)
                    if !entry.username.isEmpty {
                        Text(entry.username).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .tag(entry.id)
                .contextMenu {
                    Button(L("Kullanıcı adını kopyala", "Copy username")) { state.copy(entry.username, label: L("Kullanıcı adı", "Username")) }
                    Button(L("Parolayı kopyala", "Copy password")) { state.copy(entry.password, label: L("Parola", "Password")) }
                    Divider()
                    Button(L("Düzenle", "Edit")) { editing = entry }
                    Button(L("Sil", "Delete"), role: .destructive) { pendingDelete = entry }
                }
            }
            .searchable(text: $search, placement: .sidebar, prompt: L("Ara", "Search"))
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView(search.isEmpty ? L("Henüz kayıt yok", "No entries yet") : L("Sonuç yok", "No results"),
                                           systemImage: search.isEmpty ? "key" : "magnifyingglass",
                                           description: Text(search.isEmpty ? L("＋ ile ilk parolanızı ekleyin.", "Add your first password with ＋.") : ""))
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let id = selection, let entry = state.entries.first(where: { $0.id == id }) {
                EntryDetailView(entry: entry, onEdit: { editing = entry }, onDelete: { pendingDelete = entry })
            } else {
                ContentUnavailableView(L("Bir kayıt seçin", "Select an entry"), systemImage: "lock.open")
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button { editing = Entry() } label: { Label(L("Yeni kayıt", "New entry"), systemImage: "plus") }
                    .keyboardShortcut("n", modifiers: .command)
                Button { showGenerator = true } label: { Label(L("Parola üretici", "Password generator"), systemImage: "wand.and.stars") }
                    .keyboardShortcut("g", modifiers: .command)
                Menu {
                    Button(L("Ana parolayı değiştir…", "Change master password…")) { showChangePassword = true }
                    Button(L("Şifreli yedeği dışa aktar…", "Export encrypted backup…")) { state.exportBackup() }
                    Button(L("Şifreli yedeği içe aktar…", "Import encrypted backup…")) { showImport = true }
                    LanguagePicker(state: state)
                } label: { Label(L("Ayarlar", "Settings"), systemImage: "gearshape") }
                Button { state.lock() } label: { Label(L("Kilitle", "Lock"), systemImage: "lock") }
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
        .sheet(isPresented: $showImport) {
            ImportBackupView()
        }
        .confirmationDialog(L("“\(pendingDelete?.title ?? "")” silinsin mi?", "Delete “\(pendingDelete?.title ?? "")”?"),
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button(L("Sil", "Delete"), role: .destructive) {
                if let e = pendingDelete {
                    state.delete(e.id)
                    if selection == e.id { selection = nil }
                }
                pendingDelete = nil
            }
        } message: { Text(L("Bu işlem geri alınamaz.", "This cannot be undone.")) }
        .alert(L("Hata", "Error"), isPresented: Binding(get: { state.errorMessage != nil },
                                            set: { if !$0 { state.errorMessage = nil } })) {
            Button(L("Tamam", "OK")) {}
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
                row(L("Kullanıcı adı", "Username"), entry.username) {
                    state.copy(entry.username, label: L("Kullanıcı adı", "Username"))
                }
                LabeledContent(L("Parola", "Password")) {
                    HStack {
                        Text(reveal ? entry.password : String(repeating: "•", count: min(entry.password.count, 16)))
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                        Spacer()
                        Button { reveal.toggle() } label: {
                            Image(systemName: reveal ? "eye.slash" : "eye")
                        }.help(reveal ? L("Gizle", "Hide") : L("Göster", "Show"))
                        Button { state.copy(entry.password, label: L("Parola", "Password")) } label: {
                            Image(systemName: "doc.on.doc")
                        }.help(L("Kopyala", "Copy"))
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
                Section(L("Notlar", "Notes")) { Text(entry.notes).textSelection(.enabled) }
            }
            Section {
                LabeledContent(L("Oluşturuldu", "Created"), value: entry.createdAt.formatted(dateStyle))
                LabeledContent(L("Güncellendi", "Updated"), value: entry.updatedAt.formatted(dateStyle))
            }
        }
        .formStyle(.grouped)
        .navigationTitle(entry.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(L("Düzenle", "Edit"), action: onEdit)
                Button(role: .destructive, action: onDelete) { Label(L("Sil", "Delete"), systemImage: "trash") }
            }
        }
        .onChange(of: entry.id) { reveal = false }
    }

    private var dateStyle: Date.FormatStyle {
        Date.FormatStyle(date: .abbreviated, time: .shortened, locale: state.language.locale)
    }

    private func row(_ label: String, _ value: String, copy: @escaping () -> Void) -> some View {
        LabeledContent(label) {
            HStack {
                Text(value).textSelection(.enabled)
                Spacer()
                if !value.isEmpty {
                    Button(action: copy) { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.borderless).help(L("Kopyala", "Copy"))
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
                TextField(L("Başlık", "Title"), text: $entry.title)
                TextField(L("Kullanıcı adı / e-posta", "Username / email"), text: $entry.username)
                HStack {
                    Group {
                        if reveal { TextField(L("Parola", "Password"), text: $entry.password) }
                        else { SecureField(L("Parola", "Password"), text: $entry.password) }
                    }.font(.body.monospaced())
                    Button { reveal.toggle() } label: { Image(systemName: reveal ? "eye.slash" : "eye") }
                        .buttonStyle(.borderless)
                    Button { showGenerator.toggle() } label: { Image(systemName: "wand.and.stars") }
                        .buttonStyle(.borderless).help(L("Parola üret", "Generate password"))
                        .popover(isPresented: $showGenerator) {
                            GeneratorPanel { entry.password = $0; reveal = true; showGenerator = false }
                                .padding().frame(width: 380)
                        }
                }
                StrengthBar(password: entry.password)
                TextField("URL", text: $entry.url)
                TextField(L("Notlar", "Notes"), text: $entry.notes, axis: .vertical).lineLimit(3...8)
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button(L("Vazgeç", "Cancel"), role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L("Kaydet", "Save")) { onSave(entry); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(entry.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }.padding()
        }
        .frame(width: 480)
    }
}
