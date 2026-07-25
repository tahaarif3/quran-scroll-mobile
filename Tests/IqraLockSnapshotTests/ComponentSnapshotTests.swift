import XCTest
import SwiftUI
import SnapshotTesting
import IqraLockKit

final class ComponentSnapshotTests: XCTestCase {
    func testChunkyButtonPrimary() {
        let view = ChunkyButton("Continue", kind: .primary) {}
            .padding()
            .background(IQColor.bgSand)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 393, height: 80)))
    }

    func testOptionRowSelected() {
        let view = VStack(spacing: 12) {
            OptionRow(title: "More than 8h", isSelected: false) {}
            OptionRow(title: "More than 8h", isSelected: true) {}
        }
        .padding()
        .background(IQColor.bgSand)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 393, height: 160)))
    }

    func testHighlightedText() {
        let view = HighlightedText("locks **distracting apps**", style: .h1)
            .padding()
            .background(IQColor.bgSand)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 393, height: 120)))
    }
}
