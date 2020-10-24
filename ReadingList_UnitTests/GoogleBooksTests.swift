import XCTest
import Foundation
import CoreData
@testable import ReadingList

class GoogleBooksTests: XCTestCase {

    var testContainer: NSPersistentContainer!

    override func setUp() {
        super.setUp()
        testContainer = NSPersistentContainer(inMemoryStoreWithName: "books")
        testContainer.loadPersistentStores { _, _ in }
    }

    func dataFromFile(withName name: String, ofType fileType: String) -> Data {
        let path = Bundle(for: type(of: self)).path(forResource: name, ofType: fileType)!
        return try! Data(contentsOf: URL(fileURLWithPath: path))
    }

    func testGoogleBooksFetchParsing() {
        let jsonData = dataFromFile(withName: "GoogleBooksFetchResult", ofType: "json")
        let parseResult = try! XCTUnwrap(try! GoogleBooksApi().parseFetchResults(jsonData))

        XCTAssertEqual("The Sellout", parseResult.title)
        XCTAssertEqual(1, parseResult.authors.count)
        XCTAssertEqual("Paul Beatty", parseResult.authors.first)
        XCTAssertEqual("Fiction", parseResult.subjects[0])
        XCTAssertEqual("Satire", parseResult.subjects[1])
        XCTAssertEqual(304, parseResult.pageCount)
        XCTAssertEqual(9781786070166, parseResult.isbn13?.int)
        XCTAssertEqual("Oneworld Publications", parseResult.publisher)
        XCTAssertNotNil(parseResult.description)

        let book = Book(context: testContainer.viewContext)
        book.populate(fromFetchResult: parseResult)
        XCTAssertEqual(book.authorSort, "beatty.paul")
        XCTAssertEqual(book.authors.fullNames, "Paul Beatty")
    }

    func testGoogleBooksSearchParsing() {
        let jsonData = dataFromFile(withName: "GoogleBooksSearchResult", ofType: "json")
        let parseResult = try! GoogleBooksApi().parseSearchResults(jsonData)

        // There are 3 results with no author, which we expect to not show up in the list. Hence: 37.
        XCTAssertEqual(36, parseResult.count)
        for result in parseResult {
            // Everything must have an ID, a title and at least 1 author
            XCTAssertNotNil(result.id)
            XCTAssertNotNil(result.title)
            XCTAssert(!result.title.trimmingCharacters(in: .whitespaces).isEmpty)
            XCTAssertGreaterThan(result.authors.count, 0)
            XCTAssert(!result.authors.contains { $0.isEmptyOrWhitespace })
        }

        let resultsWithIsbn = parseResult.filter { $0.isbn13 != nil }.count
        XCTAssertEqual(28, resultsWithIsbn)

        let resultsWithCover = parseResult.filter { $0.thumbnailImage != nil }.count
        XCTAssertEqual(31, resultsWithCover)
    }
}
