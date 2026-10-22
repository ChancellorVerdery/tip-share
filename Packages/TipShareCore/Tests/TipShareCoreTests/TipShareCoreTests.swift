import XCTest
@testable import TipShareCore

final class TipShareCoreTests: XCTestCase {
    func testShiftTime() {
        XCTAssertEqual(ShiftTime.minutes("6:30"), 390)
        XCTAssertEqual(ShiftTime.minutes("6"), 360)
        XCTAssertEqual(ShiftTime.minutes(":45"), 45)
        XCTAssertEqual(ShiftTime.minutes("630"), 390)
        XCTAssertEqual(ShiftTime.minutes("10:05"), 605)
        XCTAssertNil(ShiftTime.minutes("6:75"))
        XCTAssertNil(ShiftTime.minutes("6:5"))
        XCTAssertNil(ShiftTime.minutes("abc"))
        XCTAssertEqual(ShiftTime.format(390), "6:30")
    }

    func testApportionAddsUp() {
        XCTAssertEqual(TipSplitter.apportion(100, weights: [1, 1, 1]), [34, 33, 33])
        XCTAssertEqual(TipSplitter.apportion(0, weights: [1, 2]), [0, 0])
        XCTAssertEqual(TipSplitter.apportion(50, weights: [0, 0]), [0, 0])
        XCTAssertEqual(TipSplitter.apportion(300, weights: [360, 180, 0]), [200, 100, 0])
    }

    func testTotalByTime() {
        let s = TipSplitter.split(total: 301, workers: [Worker(minutes: 480), Worker(minutes: 240), Worker(minutes: 180)])
        XCTAssertEqual(s.shares.map(\.amount).reduce(0, +), 301)
        XCTAssertEqual(s.shares.map(\.amount), [161, 80, 60])
    }

    func testBillsEvenSplit() {
        let s = TipSplitter.split(bills: [20: 4, 10: 2, 5: 2, 1: 10], workers: [Worker(minutes: 300), Worker(minutes: 300)])
        XCTAssertEqual(s.total, 120)
        XCTAssertEqual(s.shares.map(\.amount), [60, 60])
        XCTAssertTrue(s.leftover.isEmpty)
    }

    func testEnvelopeGetsFewestBills() {
        let s = TipSplitter.split(bills: [20: 3, 5: 4, 1: 20],
                                  workers: [Worker(minutes: 360, envelope: true), Worker(minutes: 360)])
        XCTAssertEqual(s.shares[0].amount, 50)
        XCTAssertEqual(s.shares[0].bills, [20: 2, 5: 2])
        XCTAssertEqual(s.shares[1].amount, 50)
        XCTAssertEqual(s.shares[1].bills, [20: 1, 5: 2, 1: 20])
    }

    func testUnsplittableBillIsLeftOver() {
        let s = TipSplitter.split(bills: [100: 1], workers: [Worker(minutes: 60), Worker(minutes: 60)])
        XCTAssertEqual(s.leftover, [100: 1])
        XCTAssertEqual(s.shares.map(\.amount), [0, 0])
        XCTAssertEqual(s.shares.map(\.target), [50, 50])
    }

    func testEveryBillAccountedFor() {
        let bills = [100: 2, 50: 1, 20: 7, 10: 3, 5: 5, 1: 17]
        let workers = [Worker(minutes: 412, envelope: true), Worker(minutes: 305), Worker(minutes: 250, envelope: true), Worker(minutes: 190)]
        let s = TipSplitter.split(bills: bills, workers: workers)
        for d in denominations {
            let handed = s.shares.reduce(0) { $0 + ($1.bills[d] ?? 0) } + (s.leftover[d] ?? 0)
            XCTAssertEqual(handed, bills[d] ?? 0)
        }
        for share in s.shares { XCTAssertLessThanOrEqual(share.amount, share.target) }
        XCTAssertEqual(s.shares.map(\.amount).reduce(0, +) + s.leftover.reduce(0) { $0 + $1.key * $1.value }, s.total)
    }
}
