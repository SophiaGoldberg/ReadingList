import Foundation
import CoreData
import Promises
import ReadingList_Foundation
import os.log

struct BookCSVImportSettings: Codable {
    var downloadCoverImages = true
    var downloadMetadata = false
    var overwriteExistingBooks = false
}

class BookCSVImporter {
    private let parserDelegate: BookCSVParserDelegate //swiftlint:disable:this weak_delegate

    init(format: CSVImportFormat, settings: BookCSVImportSettings) {
        let backgroundContext = PersistentStoreManager.container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
        parserDelegate = BookCSVParserDelegate(context: backgroundContext, importFormat: format, settings: settings)
    }

    func startImport(fromFileAt fileLocation: URL, _ completion: @escaping (Result<BookCSVImporter.Results, CSVImportError>) -> Void) {
        os_log("Beginning import from CSV file")
        parserDelegate.onCompletion = completion

        let parser = CSVParser(csvFileUrl: fileLocation)
        parser.delegate = parserDelegate
        parser.begin()
    }

    struct Results {
        let success: Int
        let error: Int
        let duplicate: Int
    }
}

class BookCSVParserDelegate: CSVParserDelegate {
    private let context: NSManagedObjectContext
    private let importFormat: CSVImportFormat
    private let settings: BookCSVImportSettings
    private let googleBooksApi = GoogleBooksApi()

    private var cachedSorts: [BookReadState: BookSortIndexManager]
    private var networkOperations = [Promise<Void>]()

    var onCompletion: ((Result<BookCSVImporter.Results, CSVImportError>) -> Void)?

    init(context: NSManagedObjectContext, importFormat: CSVImportFormat, settings: BookCSVImportSettings) {
        self.context = context
        self.importFormat = importFormat
        self.settings = settings

        cachedSorts = BookReadState.allCases.reduce(into: [BookReadState: BookSortIndexManager]()) { result, readState in
            // For imports, we ignore the "Add to Top" settings, and always add books downwards, in the order they appear in the CSV
            result[readState] = BookSortIndexManager(context: context, readState: readState, sortUpwards: false)
        }
    }

    func headersRead(_ headers: [String]) -> Bool {
        return headers.containsAll(importFormat.requiredHeaders)
    }

    private func createSubjects(_ subjects: [String]) -> [Subject] {
        return subjects.map {
            Subject.getOrCreate(inContext: context, withName: $0)
        }
    }

    private func attach(_ listIndexes: [BookCSVImportRow.ListIndex], to book: Book) {
        for listIndex in listIndexes {
            let list = List.getOrCreate(inContext: context, withName: listIndex.listName)
            if let existingListItem = Array(book.listItems).first(where: { $0.list == list }) {
                existingListItem.sort = listIndex.index
            } else {
                _ = ListItem(context: context, book: book, list: list, sort: listIndex.index)
            }
        }
    }

    private func populateCover(forBook book: Book, withGoogleID googleID: String) -> Promise<Void> {
        return googleBooksApi.getCover(googleBooksId: googleID)
            .then { data -> Void in
                self.context.performAndWait {
                    book.coverImage = data
                    os_log("Book supplemented with cover image for ID %s", type: .info, googleID)
                }
            }
    }

    private func overwriteMetadata(forBook book: Book, withGoogleID googleID: String) -> Promise<Void> {
        return googleBooksApi.fetch(googleBooksId: googleID, fetchCoverImage: false)
            .then { result -> Void in
                self.context.performAndWait {
                    book.populate(fromFetchResult: result)
                    os_log("Book supplemented with metadata for ID %s", type: .info, googleID)
                }
            }
    }

    func lineParseSuccess(_ values: [String: String]) {
        guard let csvRow = BookCSVImportRow(for: importFormat, row: values) else {
            invalidCount += 1
            os_log("Invalid data: no book created")
            return
        }

        // FUTURE: Batch save
        context.performAndWait { [unowned self] in
            let book: Book
            if let existingBook = Book.get(fromContext: self.context, googleBooksId: csvRow.googleBooksId, isbn: csvRow.isbn13?.string, manualBookId: csvRow.manualBookId) {
                guard settings.overwriteExistingBooks else {
                    duplicateCount += 1
                    return
                }
                book = existingBook
            } else {
                book = Book(context: self.context)
                guard let sortManager = cachedSorts[book.readState] else { preconditionFailure() }
                book.sort = sortManager.getAndIncrementSort()
            }
            book.populate(fromCsvRow: csvRow)
            book.subjects.formUnion(createSubjects(csvRow.subjects))
            attach(csvRow.lists, to: book)

            // If the book is not valid, delete it
            let objectIdForLogging = book.objectID.uriRepresentation().absoluteString
            do {
                try book.validateForUpdate()
            } catch {
                invalidCount += 1
                os_log("Invalid book: deleting book %{public}s (%{public}s)", type: .info, objectIdForLogging, error.localizedDescription)
                book.delete()
                return
            }
            os_log("Created %{public}s", objectIdForLogging)
            successCount += 1

            if let googleBooksId = book.googleBooksId {
                if settings.downloadCoverImages && book.coverImage == nil {
                    os_log("Supplementing book %{public}s with cover image from google ID %s", type: .info, objectIdForLogging, googleBooksId)
                    networkOperations.append(populateCover(forBook: book, withGoogleID: googleBooksId))
                }
                if settings.downloadMetadata {
                    os_log("Supplementing book %{public}s with metadata from google ID %s", type: .info, objectIdForLogging, googleBooksId)
                    networkOperations.append(overwriteMetadata(forBook: book, withGoogleID: googleBooksId))
                }
            }
        }
    }

    private var duplicateCount = 0
    private var invalidCount = 0
    private var successCount = 0

    func lineParseError() {
        invalidCount += 1
    }

    func onFailure(_ error: CSVImportError) {
        onCompletion?(.failure(error))
    }

    func completion() {
        any(networkOperations)
            .always(on: .main) {
                os_log("All %d network operations promises completed", type: .info, self.networkOperations.count)
                self.context.performAndWait {
                    // FUTURE: Consider tidying up any clashing list indexes
                    os_log("Saving results of CSV import (%d of %d successful)", self.successCount, self.successCount + self.invalidCount + self.duplicateCount)
                    self.context.saveAndLogIfErrored()
                }
                let results = BookCSVImporter.Results(success: self.successCount, error: self.invalidCount, duplicate: self.duplicateCount)
                self.onCompletion?(.success(results))
            }
    }
}
