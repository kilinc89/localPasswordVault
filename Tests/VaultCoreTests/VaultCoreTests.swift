import XCTest
@testable import VaultCore

final class VaultCoreTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func store() -> VaultStore {
        VaultStore(fileURL: dir.appendingPathComponent("v.lvault"), iterations: 1_000)
    }

    func testCreateSaveUnlockRoundTrip() throws {
        let s = store()
        let vault = try s.create(password: "correct horse")
        let entry = Entry(title: "GitHub", username: "ibo", password: "S3cret!pass", url: "github.com")
        try s.save(VaultPayload(entries: [entry]), with: vault)

        let (_, payload) = try s.unlock(password: "correct horse")
        XCTAssertEqual(payload.entries.count, 1)
        XCTAssertEqual(payload.entries.first?.password, "S3cret!pass")
    }

    func testPlaintextNeverOnDisk() throws {
        let s = store()
        let vault = try s.create(password: "correct horse")
        try s.save(VaultPayload(entries: [Entry(title: "Bank", password: "TopSecretValue123")]), with: vault)
        let raw = try String(decoding: Data(contentsOf: s.fileURL), as: UTF8.self)
        XCTAssertFalse(raw.contains("TopSecretValue123"))
        XCTAssertFalse(raw.contains("Bank"))
    }

    func testWrongPasswordFails() throws {
        let s = store()
        _ = try s.create(password: "correct horse")
        XCTAssertThrowsError(try s.unlock(password: "wrong password")) {
            XCTAssertEqual($0 as? VaultError, .wrongPassword)
        }
    }

    func testShortPasswordRejected() {
        XCTAssertThrowsError(try store().create(password: "short")) {
            XCTAssertEqual($0 as? VaultError, .passwordTooShort)
        }
    }

    func testCreateTwiceRejected() throws {
        let s = store()
        _ = try s.create(password: "correct horse")
        XCTAssertThrowsError(try s.create(password: "correct horse"))
    }

    func testTamperDetected() throws {
        let s = store()
        let vault = try s.create(password: "correct horse")
        try s.save(VaultPayload(entries: [Entry(title: "x")]), with: vault)
        var json = try JSONSerialization.jsonObject(with: Data(contentsOf: s.fileURL)) as! [String: Any]
        var ct = Data(base64Encoded: json["ciphertext"] as! String)!
        ct[ct.count - 1] ^= 0xFF
        json["ciphertext"] = ct.base64EncodedString()
        try JSONSerialization.data(withJSONObject: json).write(to: s.fileURL)
        XCTAssertThrowsError(try s.unlock(password: "correct horse"))
    }

    func testLockedVaultCannotSave() throws {
        let s = store()
        let vault = try s.create(password: "correct horse")
        vault.lock()
        XCTAssertTrue(vault.isLocked)
        XCTAssertThrowsError(try s.save(VaultPayload(), with: vault))
    }

    func testChangePassword() throws {
        let s = store()
        let vault = try s.create(password: "old password")
        try s.save(VaultPayload(entries: [Entry(title: "keep me")]), with: vault)
        _ = try s.changePassword(current: "old password", new: "new password")
        XCTAssertThrowsError(try s.unlock(password: "old password"))
        let (_, payload) = try s.unlock(password: "new password")
        XCTAssertEqual(payload.entries.first?.title, "keep me")
    }

    func testChangePasswordRequiresCurrent() throws {
        let s = store()
        _ = try s.create(password: "old password")
        XCTAssertThrowsError(try s.changePassword(current: "nope nope", new: "new password"))
    }

    func testExportBackupIsEncryptedCopy() throws {
        let s = store()
        let vault = try s.create(password: "correct horse")
        try s.save(VaultPayload(entries: [Entry(title: "a")]), with: vault)
        let dest = dir.appendingPathComponent("backup.lvault")
        try s.exportBackup(to: dest)
        let backup = VaultStore(fileURL: dest, iterations: 1_000)
        XCTAssertEqual(try backup.unlock(password: "correct horse").1.entries.count, 1)
    }

    func testHostileHeaderRejectedBeforeKeyDerivation() throws {
        let s = store()
        _ = try s.create(password: "correct horse")
        let original = try Data(contentsOf: s.fileURL)
        for (key, value) in [("iterations", UInt32.max as Any), ("salt", Data([1, 2]).base64EncodedString()),
                             ("kdf", "none")] {
            var json = try JSONSerialization.jsonObject(with: original) as! [String: Any]
            json[key] = value
            try JSONSerialization.data(withJSONObject: json).write(to: s.fileURL)
            XCTAssertThrowsError(try s.unlock(password: "correct horse"), key) {
                XCTAssertEqual($0 as? VaultError, .corruptFile)
            }
        }
    }

    func testExportOverwritesExistingBackup() throws {
        let s = store()
        let vault = try s.create(password: "correct horse")
        let dest = dir.appendingPathComponent("backup.lvault")
        try Data("old".utf8).write(to: dest)
        try s.save(VaultPayload(entries: [Entry(title: "a"), Entry(title: "b")]), with: vault)
        try s.exportBackup(to: dest)
        let backup = VaultStore(fileURL: dest, iterations: 1_000)
        XCTAssertEqual(try backup.unlock(password: "correct horse").1.entries.count, 2)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".tmp") }
        XCTAssertTrue(leftovers.isEmpty)
    }

    func testGeneratorLengthAndClasses() {
        for len in [8, 20, 64] {
            let p = PasswordGenerator.generate(GeneratorOptions(length: len))
            XCTAssertEqual(p.count, len)
            XCTAssertTrue(p.contains { $0.isUppercase })
            XCTAssertTrue(p.contains { $0.isLowercase })
            XCTAssertTrue(p.contains { $0.isNumber })
            XCTAssertTrue(p.contains { !$0.isLetter && !$0.isNumber })
        }
        XCTAssertEqual(PasswordGenerator.generate(GeneratorOptions(length: 3)).count, 8)
        XCTAssertEqual(PasswordGenerator.generate(GeneratorOptions(length: 500)).count, 64)
    }

    func testGeneratorExcludesAmbiguousAndRespectsClasses() {
        let o = GeneratorOptions(length: 64, uppercase: false, lowercase: true, digits: true,
                                 symbols: false, excludeAmbiguous: true)
        for _ in 0..<50 {
            let p = PasswordGenerator.generate(o)
            XCTAssertTrue(p.allSatisfy { $0.isLowercase || $0.isNumber })
            XCTAssertTrue(Set(p).isDisjoint(with: PasswordGenerator.ambiguous))
        }
    }

    func testGeneratorUniqueness() {
        let set = Set((0..<200).map { _ in PasswordGenerator.generate(GeneratorOptions()) })
        XCTAssertEqual(set.count, 200)
    }

    func testStrength() {
        XCTAssertEqual(PasswordStrength.evaluate(""), .weak)
        XCTAssertEqual(PasswordStrength.evaluate("password"), .weak)
        XCTAssertEqual(PasswordStrength.evaluate("aaaaaaaaaaaaaaaaaaaa"), .weak)
        XCTAssertGreaterThanOrEqual(PasswordStrength.evaluate(PasswordGenerator.generate(GeneratorOptions(length: 20))), .strong)
        XCTAssertEqual(PasswordStrength.evaluate(PasswordGenerator.generate(GeneratorOptions(length: 32))), .veryStrong)
    }

    func testSearch() {
        let e = Entry(title: "GitHub", username: "ibrahim", url: "https://github.com")
        XCTAssertTrue(e.matches(""))
        XCTAssertTrue(e.matches("git"))
        XCTAssertTrue(e.matches("IBRA"))
        XCTAssertFalse(e.matches("gitlab"))
    }

    func testLanguageSwitch() {
        let saved = UserDefaults.standard.string(forKey: AppLanguage.defaultsKey)
        defer { UserDefaults.standard.set(saved, forKey: AppLanguage.defaultsKey) }

        AppLanguage.current = .english
        XCTAssertEqual(VaultError.wrongPassword.errorDescription, "Incorrect master password.")
        XCTAssertEqual(Strength.weak.label, "Weak")

        AppLanguage.current = .turkish
        XCTAssertEqual(VaultError.wrongPassword.errorDescription, "Ana parola yanlış.")
        XCTAssertEqual(Strength.weak.label, "Zayıf")
    }
}
