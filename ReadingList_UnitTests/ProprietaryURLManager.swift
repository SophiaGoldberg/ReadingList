import XCTest
import Foundation
@testable import ReadingList

class ProprietaryURLManagerTests: XCTestCase {

    let urlManager = ProprietaryURLManager()

    override func setUp() {
        super.setUp()
    }

    func testUrlToAction() {
        performRoundTripTestFromURL(url: "readinglist://book/view?gbid=123456789", expectedAction: .viewBook(id: .googleBooksId("123456789")))
        performRoundTripTestFromURL(url: "readinglist://book/view?mid=abcdef", expectedAction: .viewBook(id: .manualId("abcdef")))
        performRoundTripTestFromURL(url: "readinglist://book/view?isbn=9780684833392", expectedAction: .viewBook(id: .isbn("9780684833392")))
    }

    func performRoundTripTestFromURL(url urlString: String, expectedAction: ProprietaryURLAction) {
        let url = URL(string: urlString)!
        let action = urlManager.getAction(from: url)
        XCTAssertNotNil(action)
        XCTAssertEqual(action, expectedAction)

        let roundTripActionURL = urlManager.getURL(from: action!)
        XCTAssertEqual(roundTripActionURL, url)
    }
}
