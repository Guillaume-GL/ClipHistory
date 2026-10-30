// Tests for the clipboard history logic (class History in main.swift).
// No test framework: XCTest is not available with the Command Line Tools alone.
// Run with: bash build.sh test
// Compiled together with main.swift with -D TESTING; main.swift then calls runTests()
// instead of starting the app.

import AppKit

// MARK: - Minimal assertion helper

/// Collects the failures of one test. A test passes when no failure was recorded.
final class TestContext {
    private(set) var failures: [String] = []

    func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ what: String,
                                   file: StaticString = #fileID, line: UInt = #line) {
        if actual != expected {
            failures.append("\(file):\(line) \(what): expected \(expected), got \(actual)")
        }
    }

    func expectTrue(_ condition: Bool, _ what: String,
                    file: StaticString = #fileID, line: UInt = #line) {
        if !condition {
            failures.append("\(file):\(line) \(what)")
        }
    }
}

// MARK: - Private pasteboard helpers

/// A pasteboard that only this test process knows about, so the user's clipboard
/// (NSPasteboard.general) is never read or written by the tests.
func makePrivatePasteboard() -> NSPasteboard {
    return NSPasteboard.withUniqueName()
}

/// Simulates a plain text copy, as a text editor would do.
func copyText(_ text: String, to pb: NSPasteboard) {
    pb.clearContents()
    pb.setString(text, forType: .string)
}

/// Simulates a copy from a password manager: the text comes with the
/// "org.nspasteboard.ConcealedType" marker (convention from nspasteboard.org).
func copyConcealedText(_ text: String, to pb: NSPasteboard) {
    let item = NSPasteboardItem()
    item.setString(text, forType: .string)
    let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    item.setData(Data(), forType: concealedType)
    pb.clearContents()
    pb.writeObjects([item])
}

/// Copied text of the history entries, most recent first.
/// Uses `search` (the raw copied text) rather than `label` (the display text):
/// "  A\n" is displayed as "A", so two different copies could share a label.
func texts(of entries: [Entry]) -> [String] {
    var result: [String] = []
    for entry in entries {
        result.append(entry.search)
    }
    return result
}

// MARK: - Tests

/// Criterion 2: copying "A", then "B", then "A" gives [A, B].
func testCopyingSameTextAgainMovesItToTopWithoutDuplicate(_ t: TestContext) {
    let pb = makePrivatePasteboard()
    defer { pb.releaseGlobally() }
    let history = History()

    copyText("A", to: pb)
    _ = history.capture(pb)
    copyText("B", to: pb)
    _ = history.capture(pb)
    copyText("A", to: pb)
    _ = history.capture(pb)

    let historyTexts = texts(of: history.entries)
    t.expectEqual(historyTexts, ["A", "B"], "history after copying A, B, A")
}

/// Criterion 3: a copy carrying org.nspasteboard.ConcealedType is not recorded.
/// A normal copy is captured first, to prove the history does record ordinary copies
/// (otherwise an empty history would pass for the wrong reason).
func testConcealedCopyIsNotRecorded(_ t: TestContext) {
    let pb = makePrivatePasteboard()
    defer { pb.releaseGlobally() }
    let history = History()

    copyText("visible", to: pb)
    _ = history.capture(pb)
    copyConcealedText("my-secret-password", to: pb)
    _ = history.capture(pb)

    let historyTexts = texts(of: history.entries)
    t.expectEqual(historyTexts, ["visible"], "history after a normal copy then a concealed copy")
}

/// Criterion 4: searching "ete" finds "Été à Paris" (case- and accent-insensitive).
/// A non-matching entry is present to check the search actually filters.
func testSearchIgnoresCaseAndAccents(_ t: TestContext) {
    let pb = makePrivatePasteboard()
    defer { pb.releaseGlobally() }
    let history = History()

    copyText("Été à Paris", to: pb)
    _ = history.capture(pb)
    copyText("Hiver à Lyon", to: pb)
    _ = history.capture(pb)

    let results = history.filtered("ete")

    let resultTexts = texts(of: results)
    t.expectEqual(resultTexts, ["Été à Paris"], "search results for \"ete\"")
}

// MARK: - Localization tests (strings / localized in main.swift)

/// The key every localization test relies on (agreed with the user: the "Show history" menu entry).
let showHistoryKey = "menu.showHistory"

/// French and English texts of the "Show history" entry, read from the table so the tests
/// do not depend on the exact wording. Records a failure and returns nil if the key is missing.
func showHistoryTexts(_ t: TestContext) -> (fr: String, en: String)? {
    guard let entry = strings[showHistoryKey] else {
        t.expectTrue(false, "strings has no entry for \"\(showHistoryKey)\"")
        return nil
    }
    // If both texts were identical, "returns French" and "returns English" could not be
    // told apart and the language tests below would pass for the wrong reason.
    t.expectTrue(entry.fr != entry.en, "French and English texts of \"\(showHistoryKey)\" differ")
    return entry
}

/// Localization criterion 1: a first preferred language starting with "fr" gives French.
/// "fr-FR" and "fr-CA" are the forms Locale.preferredLanguages returns for regional French.
func testLocalizedReturnsFrenchWhenFirstLanguageIsFrench(_ t: TestContext) {
    guard let expected = showHistoryTexts(t) else { return }

    for language in ["fr", "fr-FR", "fr-CA"] {
        let text = localized(showHistoryKey, languages: [language])
        t.expectEqual(text, expected.fr, "localized text for languages [\(language)]")
    }
}

/// Localization criterion 1: any other first language, or no language at all, gives English.
func testLocalizedReturnsEnglishForOtherOrNoLanguage(_ t: TestContext) {
    guard let expected = showHistoryTexts(t) else { return }

    let languageLists: [[String]] = [["en"], ["de"], ["ja"], []]
    for languages in languageLists {
        let text = localized(showHistoryKey, languages: languages)
        t.expectEqual(text, expected.en, "localized text for languages \(languages)")
    }
}

/// Localization criterion 1 (rule detail): only the FIRST preferred language matters.
/// ["en", "fr"] -> English, even though French is in the list.
/// ["fr", "en"] -> French, so the rule is not simply "always English when there are several".
func testLocalizedOnlyLooksAtFirstPreferredLanguage(_ t: TestContext) {
    guard let expected = showHistoryTexts(t) else { return }

    let englishFirst = localized(showHistoryKey, languages: ["en", "fr"])
    t.expectEqual(englishFirst, expected.en, "localized text for languages [en, fr]")

    let germanFirst = localized(showHistoryKey, languages: ["de", "fr-FR"])
    t.expectEqual(germanFirst, expected.en, "localized text for languages [de, fr-FR]")

    let frenchFirst = localized(showHistoryKey, languages: ["fr", "en"])
    t.expectEqual(frenchFirst, expected.fr, "localized text for languages [fr, en]")
}

/// Localization criterion 2: every key has a non-empty French text and a non-empty English text.
/// Keys are sorted so failures are reported in a stable order.
func testEveryStringHasFrenchAndEnglishText(_ t: TestContext) {
    t.expectTrue(!strings.isEmpty, "strings table is not empty")

    for key in strings.keys.sorted() {
        let entry = strings[key]!
        t.expectTrue(!entry.fr.isEmpty, "French text of \"\(key)\" is not empty")
        t.expectTrue(!entry.en.isEmpty, "English text of \"\(key)\" is not empty")
    }
}

/// Localization criterion 3: the "Show history" entry shows the current shortcut
/// (hotKeyLabel, e.g. "⌃⌘V") in both languages, so changing the shortcut updates the menu.
func testShowHistoryEntryContainsHotKeyLabel(_ t: TestContext) {
    guard let entry = strings[showHistoryKey] else {
        t.expectTrue(false, "strings has no entry for \"\(showHistoryKey)\"")
        return
    }

    t.expectTrue(entry.fr.contains(hotKeyLabel),
                 "French text \"\(entry.fr)\" contains hotKeyLabel \"\(hotKeyLabel)\"")
    t.expectTrue(entry.en.contains(hotKeyLabel),
                 "English text \"\(entry.en)\" contains hotKeyLabel \"\(hotKeyLabel)\"")
}

/// Localization: an unknown key (e.g. a typo like "menu.qiut") returns the key itself,
/// so the mistake shows up in the menu instead of an empty item or a crash.
func testUnknownKeyReturnsTheKeyItself(_ t: TestContext) {
    let missingKey = "missing.key"

    let frenchText = localized(missingKey, languages: ["fr"])
    t.expectEqual(frenchText, missingKey, "localized text for an unknown key, languages [fr]")

    let englishText = localized(missingKey, languages: ["en"])
    t.expectEqual(englishText, missingKey, "localized text for an unknown key, languages [en]")
}

// MARK: - Runner

/// Runs every test, prints each name with PASS/FAIL and failure details,
/// then exits with status 0 if everything passed, 1 otherwise.
func runTests() {
    let tests: [(name: String, run: (TestContext) -> Void)] = [
        ("testCopyingSameTextAgainMovesItToTopWithoutDuplicate", testCopyingSameTextAgainMovesItToTopWithoutDuplicate),
        ("testConcealedCopyIsNotRecorded", testConcealedCopyIsNotRecorded),
        ("testSearchIgnoresCaseAndAccents", testSearchIgnoresCaseAndAccents),
        ("testLocalizedReturnsFrenchWhenFirstLanguageIsFrench", testLocalizedReturnsFrenchWhenFirstLanguageIsFrench),
        ("testLocalizedReturnsEnglishForOtherOrNoLanguage", testLocalizedReturnsEnglishForOtherOrNoLanguage),
        ("testLocalizedOnlyLooksAtFirstPreferredLanguage", testLocalizedOnlyLooksAtFirstPreferredLanguage),
        ("testEveryStringHasFrenchAndEnglishText", testEveryStringHasFrenchAndEnglishText),
        ("testShowHistoryEntryContainsHotKeyLabel", testShowHistoryEntryContainsHotKeyLabel),
        ("testUnknownKeyReturnsTheKeyItself", testUnknownKeyReturnsTheKeyItself),
    ]

    // Criterion 1: the tests must not touch the user's clipboard.
    // changeCount increases on every write to the general pasteboard; reading it changes nothing.
    let generalChangeCountBefore = NSPasteboard.general.changeCount

    var failedNames: [String] = []
    for test in tests {
        let context = TestContext()
        test.run(context)
        if context.failures.isEmpty {
            print("PASS  \(test.name)")
        } else {
            print("FAIL  \(test.name)")
            for failure in context.failures {
                print("      \(failure)")
            }
            failedNames.append(test.name)
        }
    }

    let clipboardCheckName = "testUserClipboardIsUntouched"
    let generalChangeCountAfter = NSPasteboard.general.changeCount
    if generalChangeCountAfter == generalChangeCountBefore {
        print("PASS  \(clipboardCheckName)")
    } else {
        print("FAIL  \(clipboardCheckName)")
        print("      NSPasteboard.general changeCount went from \(generalChangeCountBefore) to \(generalChangeCountAfter)")
        failedNames.append(clipboardCheckName)
    }

    let total = tests.count + 1
    print("")
    if failedNames.isEmpty {
        print("All \(total) tests passed.")
        exit(0)
    }
    print("\(failedNames.count) of \(total) tests failed:")
    for name in failedNames {
        print("  - \(name)")
    }
    exit(1)
}
