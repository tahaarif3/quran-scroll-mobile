import XCTest
import SwiftData
@testable import IqraLockKit

final class PrayerLogTests: XCTestCase {
    func testPrayerLogStoresCompletedSalah() {
        let log = PrayerLog(day: Date())
        XCTAssertTrue(log.completed.isEmpty)
        log.completed = [PrayerName.fajr.rawValue, PrayerName.maghrib.rawValue]
        XCTAssertEqual(log.completed.count, 2)
        XCTAssertTrue(log.completed.contains("fajr"))
        XCTAssertEqual(log.completedRaw, "fajr|maghrib")
    }

    func testPrayerLogNormalizesDayToStartOfDay() {
        let afternoon = Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!
        let log = PrayerLog(day: afternoon)
        XCTAssertEqual(
            Calendar.current.startOfDay(for: log.day),
            Calendar.current.startOfDay(for: afternoon)
        )
    }


    func testTogglePersistsPrimitiveCompletion() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let today = Calendar.current.startOfDay(for: Date())

        try PrayerLogStore.toggle(.fajr, on: today, context: context)

        let verificationContext = ModelContext(container)
        let logs = try verificationContext.fetch(FetchDescriptor<PrayerLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].completed, [PrayerName.fajr.rawValue])
        XCTAssertEqual(logs[0].completedRaw, PrayerName.fajr.rawValue)
        XCTAssertEqual(
            try PrayerLogStore.completed(on: today, context: verificationContext),
            Set([PrayerName.fajr.rawValue])
        )
    }

    func testSecondToggleReusesSameCalendarDayRow() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let morning = Calendar.current.startOfDay(for: Date())
        let evening = Calendar.current.date(byAdding: .hour, value: 18, to: morning)!

        try PrayerLogStore.toggle(.fajr, on: morning, context: context)
        try PrayerLogStore.toggle(.dhuhr, on: evening, context: context)

        let verificationContext = ModelContext(container)
        let logs = try verificationContext.fetch(FetchDescriptor<PrayerLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(Set(logs[0].completed), Set(["fajr", "dhuhr"]))
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: PrayerLog.self, configurations: configuration)
    }
}
