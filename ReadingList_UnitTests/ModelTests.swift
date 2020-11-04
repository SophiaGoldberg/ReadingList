import XCTest
import Foundation
import CoreData
@testable import ReadingList

class ModelTests: XCTestCase {

    var testContainer: NSPersistentContainer!

    override func setUp() {
        super.setUp()
        testContainer = NSPersistentContainer(inMemoryStoreWithName: "books")
        testContainer.loadPersistentStores { _, _ in }
    }

    func testBookSort() {
        let originalToReadMaxSort = Book.maxSort(with: .toRead, from: testContainer.viewContext) ?? -1
        let originalToReadMinSort = Book.minSort(with: .toRead, from: testContainer.viewContext) ?? 0
        let originalReadingMaxSort = Book.maxSort(with: .reading, from: testContainer.viewContext) ?? -1

        // Ensure settings are default
        GeneralSettings.addBooksToTopOfCustom = false

        func createBook(_ readState: BookReadState, _ title: String) -> Book {
            let book = Book(context: testContainer.viewContext)
            if readState == .reading {
                book.setReading(started: Date())
            }
            if readState == .finished {
                book.setFinished(started: Date(), finished: Date())
            }
            book.title = title
            book.manualBookId = UUID().uuidString
            book.authors = [Author(lastName: "Lastname", firstNames: "Firstname")]
            book.updateSortIndex()
            return book
        }

        // Add two books and check sort increments for both
        let book = createBook(.toRead, "title1")
        XCTAssertEqual(originalToReadMaxSort + 1, book.sort)
        XCTAssertEqual(Book.maxSort(with: .toRead, from: testContainer.viewContext), book.sort)
        try! testContainer.viewContext.save()

        let book2 = createBook(.toRead, "title2")
        XCTAssertEqual(originalToReadMaxSort + 2, book2.sort)
        XCTAssertEqual(Book.maxSort(with: .toRead, from: testContainer.viewContext), book2.sort)
        try! testContainer.viewContext.save()

        // Start reading book2; check its sort is reset, and the maxSort of toRead goes down
        book2.setReading(started: Date())
        book2.updateSortIndex()
        XCTAssertEqual(originalReadingMaxSort + 1, book2.sort)
        XCTAssertEqual(Book.maxSort(with: .toRead, from: testContainer.viewContext), originalToReadMaxSort + 1)
        try! testContainer.viewContext.save()

        // Add book to .reading and check sort increments, but toRead sort unchanged
        let book3 = createBook(.reading, "title3")
        XCTAssertEqual(originalReadingMaxSort + 2, book3.sort)
        XCTAssertEqual(Book.maxSort(with: .toRead, from: testContainer.viewContext), originalToReadMaxSort + 1)
        try! testContainer.viewContext.save()

        // Update the setting
        GeneralSettings.addBooksToTopOfCustom = true

        // Add a book and check the sort is below other books
        let book4 = createBook(.toRead, "title4")
        XCTAssertEqual(originalToReadMinSort - 1, book4.sort)
        XCTAssertEqual(Book.minSort(with: .toRead, from: testContainer.viewContext)!, book4.sort)
        try! testContainer.viewContext.save()

        // Add another - check that the sort goes down
        let book5 = createBook(.toRead, "title5")
        try! testContainer.viewContext.save()
        XCTAssertEqual(originalToReadMinSort - 2, book5.sort)
        XCTAssertEqual(Book.minSort(with: .toRead, from: testContainer.viewContext)!, book5.sort)
    }

    func testAuthorCalculatedProperties() {
        let book = Book(context: testContainer.viewContext)
        book.title = "title"
        book.manualBookId = UUID().uuidString
        book.authors = [Author(lastName: "Birkhäuser", firstNames: "Wahlöö"),
                                    Author(lastName: "Sjöwall", firstNames: "Maj")]
        try! testContainer.viewContext.save()

        XCTAssertEqual("birkhauser.wahloo..sjowall.maj", book.authorSort)
        XCTAssertEqual("Wahlöö Birkhäuser, Maj Sjöwall", book.authors.fullNames)
    }

    func testIsbnValidation() {
        let book = Book(context: testContainer.viewContext)
        book.title = "Test"
        book.authors = [Author(lastName: "Test", firstNames: "Author")]
        book.manualBookId = UUID().uuidString

        book.isbn13 = 1234567891234
        XCTAssertThrowsError(try book.validateForUpdate(), "Valid ISBN")

        book.isbn13 = 9781786070166
        XCTAssertNoThrow(try book.validateForUpdate(), "Invalid ISBN")
    }
}
