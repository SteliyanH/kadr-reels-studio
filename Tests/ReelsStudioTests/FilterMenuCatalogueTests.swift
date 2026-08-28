import XCTest
import Kadr
@testable import ReelsStudio

/// The add-filter menu is driven by kadr's catalogue, not a hand-written list.
///
/// This is the guard, not the menu: the failure it exists to catch is a filter
/// added to kadr that never appears in the app, which no UI test would notice
/// because the missing entry is missing from the expectation too.
final class FilterMenuCatalogueTests: XCTestCase {

    func testEveryInsertableKindProducesAFilterOfThatKind() {
        for kind in FilterKind.insertable {
            guard let filter = kind.defaultFilter else {
                return XCTFail("\(kind) is insertable but has no default filter")
            }
            XCTAssertEqual(filter.kind, kind)
        }
    }

    func testTheMenuOffersEveryFilterExceptTheTwoNeedingAPayload() {
        // .lut needs a cube file and .chromaKey needs a colour and threshold —
        // both route through their own pickers. Everything else must be one tap.
        let offered = Set(FilterKind.insertable)
        let expected = Set(FilterKind.allCases).subtracting([.lut, .chromaKey])
        XCTAssertEqual(offered, expected)
    }

    func testChromaKeyIsNotOfferedAsAOneTapInsert() {
        // It has its own sheet; offering it here too would insert a key with a
        // colour nobody chose.
        XCTAssertFalse(FilterKind.insertable.contains(.chromaKey))
    }

    func testEveryOfferedKindHasAName() {
        for kind in FilterKind.insertable {
            XCTAssertFalse(kind.displayName.isEmpty, "\(kind) would render a blank menu row")
        }
    }
}
