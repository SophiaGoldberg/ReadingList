import XCTest
import Foundation
import CoreData
@testable import ReadingList

class CSVCharacterEscapeTests: XCTestCase {
    var testContainer: NSPersistentContainer!

    override func setUp() {
        super.setUp()
        testContainer = NSPersistentContainer(inMemoryStoreWithName: "books")
        testContainer.loadPersistentStores { _, _ in }
    }

    func testCharacterEscapingAndUnescaping() {
        let book = Book(context: testContainer.viewContext)
        book.title = "Book title"
        book.authors = [
            Author(lastName: #"Author; 1\; Last, name\, with\\, weird\\; chars"#, firstNames: #"Author; 1\; First, names\, with\\, weird\\; chars"#),
            Author(lastName: #"Author; 2\; Last, name\, with\\, weird\\; chars"#, firstNames: #"Author; 2\; First, names\, with\\, weird\\; chars"#),
            Author(lastName: #"Author 3"#, firstNames: nil),
            Author(lastName: #"Author,4"#, firstNames: nil),
            Author(lastName: #"Author\,5"#, firstNames: nil),
            Author(lastName: #"Author\\,6"#, firstNames: nil)
        ]
        book.subjects.formUnion([
            Subject(context: testContainer.viewContext, name: "Subject,1"),
            Subject(context: testContainer.viewContext, name: #"Subject\Two\\Subject\,Two\\,Subject_Two"#)
        ])

        var csvValues = [String: String]()
        for column in BookCSVColumn.export.columns {
            csvValues[column.header] = column.cellValue(book) ?? ""
        }
        let importRow = BookCSVImportRow(readingListRow: csvValues)!
        XCTAssertEqual(book.title, importRow.title)
        XCTAssertEqual(book.authors, importRow.authors)
        XCTAssertEqual(Array(book.subjects.map { $0.name }), importRow.subjects)
    }
}
