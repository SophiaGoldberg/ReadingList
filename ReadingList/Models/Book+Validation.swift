import Foundation
import ReadingList_Foundation

extension Book {
    @objc func validateAuthors(_ value: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        // nil authors property will be validated by the validation set on the model
        guard let authors = value.pointee as? [Author] else { return }
        if authors.isEmpty {
            throw BookValidationError.noAuthors.NSError()
        }
    }

    @objc func validateTitle(_ value: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        // nil title property will be validated by the validation set on the model
        guard let title = value.pointee as? String else { return }
        if title.isEmptyOrWhitespace {
            throw BookValidationError.missingTitle.NSError()
        }
    }

    @objc func validateIsbn13(_ value: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        guard let isbn13 = value.pointee as? Int64 else { return }
        if !ISBN13.isValid(isbn13) {
            throw BookValidationError.invalidIsbn.NSError()
        }
    }

    @objc func validateLanguageCode(_ value: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        guard let languageCode = value.pointee as? String else { return }
        if LanguageIso639_1(rawValue: languageCode) == nil {
            throw BookValidationError.invalidLanguageCode.NSError()
        }
    }

    override func validateForUpdate() throws {
        try super.validateForUpdate()
        try interPropertyValiatation()
    }

    override func validateForInsert() throws {
        try super.validateForInsert()
        try interPropertyValiatation()
    }

    func interPropertyValiatation() throws {
        switch readState {
        case .toRead:
            if startedReading != nil || finishedReading != nil {
                throw BookValidationError.invalidReadDates.NSError()
            }
        case .reading:
            if startedReading == nil || finishedReading != nil {
                throw BookValidationError.invalidReadDates.NSError()
            }
        case .finished:
            if startedReading == nil || finishedReading == nil {
                throw BookValidationError.invalidReadDates.NSError()
            }
        }
        if readState != .reading && (currentPage != nil || currentPercentage != nil) {
            throw BookValidationError.presentCurrentPage.NSError()
        }
        if googleBooksId == nil && manualBookId == nil {
            throw BookValidationError.missingIdentifier.NSError()
        }
    }
}

enum BookValidationError: Int {
    case missingTitle = 1
    case invalidIsbn = 2
    case invalidReadDates = 3
    case invalidLanguageCode = 4
    case missingIdentifier = 5
    case noAuthors = 6
    case presentCurrentPage = 7
}

extension BookValidationError {
    var description: String {
        switch self {
        case .missingTitle: return "Title must be non-empty or whitespace"
        case .invalidIsbn: return "Isbn13 must be a valid ISBN"
        case .invalidReadDates: return "StartedReading and FinishedReading must align with ReadState"
        case .invalidLanguageCode: return "LanguageCode must be an ISO-639.1 value"
        case .missingIdentifier: return "GoogleBooksId and ManualBooksId cannot both be nil"
        case .noAuthors: return "Authors array must be non-empty"
        case .presentCurrentPage: return "CurrentPage must be nil when not Currently Reading"
        }
    }

    func NSError() -> NSError {
        return Foundation.NSError(domain: "BookErrorDomain", code: self.rawValue, userInfo: [NSLocalizedDescriptionKey: self.description])
    }
}
