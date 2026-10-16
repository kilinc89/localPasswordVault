import AppKit
import SwiftUI
import VaultCore

@MainActor
final class AppState: ObservableObject {
    enum Phase { case setup, locked, unlocked }

    @Published private(set) var phase: Phase
    @Published var entries: [Entry] = []
    @Published var errorMessage: String?
    @Published var toast: String?
    @Published var language = AppLanguage.current {
        didSet { AppLanguage.current = language }
    }

    let store: VaultStore
    let autoLockInterval: TimeInterval = 5 * 60
    let clipboardClearDelay: TimeInterval = 30

    private var vault: UnlockedVault?
    private var lastActivity = Date()
    private var timer: Timer?
    private var eventMonitor: Any?
    private var clipboardTask: Task<Void, Never>?

    init(store: VaultStore = VaultStore()) {
        self.store = store
        phase = store.exists ? .locked : .setup
        observeSystemLockEvents()
    }

    // MARK: F1 – create / unlock

    func createVault(password: String, confirm: String) {
        guard password == confirm else { errorMessage = L("Parolalar eşleşmiyor.", "Passwords do not match."); return }
        run {
            self.vault = try self.store.create(password: password)
            self.entries = []
            self.didUnlock()
        }
    }

    func unlock(password: String) {
        run {
            let (vault, payload) = try self.store.unlock(password: password)
            self.vault = vault
            self.entries = payload.entries.sorted(by: Self.order)
            self.didUnlock()
        }
    }

    // MARK: F9 – lock

    func lock() {
        guard phase == .unlocked else { return }
        vault?.lock()
        vault = nil
        entries = []
        phase = .locked
        stopActivityTracking()
    }

    // MARK: F4 – entries

    func upsert(_ entry: Entry) {
        var e = entry
        e.updatedAt = Date()
        var updated = entries
        if let i = updated.firstIndex(where: { $0.id == e.id }) {
            updated[i] = e
        } else {
            e.createdAt = Date()
            updated.append(e)
        }
        commit(updated.sorted(by: Self.order))
    }

    func delete(_ id: Entry.ID) {
        commit(entries.filter { $0.id != id })
    }

    // MARK: F11 / F12

    func changePassword(current: String, new: String, confirm: String) -> Bool {
        guard new == confirm else { errorMessage = L("Yeni parolalar eşleşmiyor.", "New passwords do not match."); return false }
        var ok = false
        run {
            let (vault, _) = try self.store.changePassword(current: current, new: new)
            self.vault = vault
            ok = true
            self.toast = L("Ana parola değiştirildi.", "Master password changed.")
        }
        return ok
    }

    func exportBackup() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "LocalVault-\(L("yedek", "backup"))-\(Self.dateStamp()).lvault"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        run {
            try self.store.exportBackup(to: url)
            self.toast = L("Şifreli yedek kaydedildi.", "Encrypted backup saved.")
        }
    }

    // MARK: F8 – clipboard

    func copy(_ value: String, label: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(value, forType: .string)
        let changeCount = pb.changeCount
        toast = L("\(label) kopyalandı — \(Int(clipboardClearDelay)) sn sonra temizlenecek.",
                  "\(label) copied — clipboard clears in \(Int(clipboardClearDelay)) s.")
        clipboardTask?.cancel()
        clipboardTask = Task { [clipboardClearDelay] in
            try? await Task.sleep(for: .seconds(clipboardClearDelay))
            guard !Task.isCancelled else { return }
            // Only clear if the user hasn't copied something else in the meantime.
            if pb.changeCount == changeCount { pb.clearContents() }
        }
    }

    // MARK: private

    /// Writes `updated` to disk and only then publishes it, so the UI never shows unsaved changes.
    private func commit(_ updated: [Entry]) {
        guard let vault else { return }
        run {
            try self.store.save(VaultPayload(entries: updated), with: vault)
            self.entries = updated
        }
    }

    private func run(_ body: () throws -> Void) {
        do {
            try body()
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func didUnlock() {
        phase = .unlocked
        startActivityTracking()
    }

    private func startActivityTracking() {
        lastActivity = Date()
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel, .mouseMoved]
        ) { [weak self] event in
            self?.lastActivity = Date()
            return event
        }
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if Date().timeIntervalSince(self.lastActivity) >= self.autoLockInterval { self.lock() }
            }
        }
    }

    private func stopActivityTracking() {
        timer?.invalidate()
        timer = nil
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
    }

    private func observeSystemLockEvents() {
        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.lock() }
            }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.lock() }
        }
    }

    private static func order(_ a: Entry, _ b: Entry) -> Bool {
        a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
    }

    private static func dateStamp() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }
}
