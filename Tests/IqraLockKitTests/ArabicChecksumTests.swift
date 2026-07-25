import XCTest
@testable import IqraLockKit

final class ArabicChecksumTests: XCTestCase {
    func testBundledArabicChecksumMatchesSidecar() throws {
        // Ensures CC BY verbatim obligation: display Arabic must not drift.
        guard let repo = try? BundledQuranRepository() else {
            throw XCTSkip("quran.sqlite not in test host bundle — run on Mac after xcodegen")
        }
        let checksum = try repo.arabicChecksum()
        XCTAssertEqual(checksum.count, 64)

        let candidates = [
            Bundle(for: BundledQuranRepository.self).url(forResource: "arabic", withExtension: "sha256"),
            Bundle.main.url(forResource: "arabic", withExtension: "sha256")
        ].compactMap { $0 }
        if let url = candidates.first,
           let expected = try? String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines) {
            XCTAssertEqual(checksum, expected)
        }

        // Spot-check known mushaf page boundary: Al-Fatihah is page 1
        let page1 = try repo.page(1)
        XCTAssertEqual(page1.pageNumber, 1)
        XCTAssertFalse(page1.ayahs.isEmpty)

        // Al-Mulk starts near end of mushaf
        let mulk = try repo.ayah(surah: 67, ayah: 1)
        XCTAssertGreaterThanOrEqual(mulk.page, 560)
        XCTAssertLessThanOrEqual(mulk.page, 570)

        XCTAssertEqual(try repo.allSurahs().count, 114)
    }
}
