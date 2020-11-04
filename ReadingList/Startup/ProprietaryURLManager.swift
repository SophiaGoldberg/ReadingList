import Foundation
import UIKit
import os.log

enum ProprietaryURLAction: Equatable {
    case viewBook(id: BookIdentifier)
    case editBookReadLog(id: BookIdentifier)
    case addBookSearchOnline
    case addBookScanBarcode
    case addBookManually
}

fileprivate extension ProprietaryURLAction {
    var host: URLHost {
        switch self {
        case .viewBook(id: _): return .book
        case .editBookReadLog(id: _): return .book
        case .addBookSearchOnline: return .book
        case .addBookScanBarcode: return .book
        case .addBookManually: return .book
        }
    }

    var path: URLPath {
        switch self {
        case .viewBook(id: _): return .view
        case .editBookReadLog(id: _): return .editReadLog
        case .addBookScanBarcode, .addBookManually, .addBookSearchOnline: return .add
        }
    }

    var query: [URLQueryItem] {
        switch self {
        case .editBookReadLog(id: let id): return id.urlQuery
        case .viewBook(id: let id): return id.urlQuery
        case .addBookManually: return [URLQueryItem(name: URLQueryItemKey.addMethod.rawValue, value: AddMethod.manual.rawValue)]
        case .addBookSearchOnline: return [URLQueryItem(name: URLQueryItemKey.addMethod.rawValue, value: AddMethod.search.rawValue)]
        case .addBookScanBarcode: return [URLQueryItem(name: URLQueryItemKey.addMethod.rawValue, value: AddMethod.barcode.rawValue)]
        }
    }
}

fileprivate extension BookIdentifier {
    var urlQuery: [URLQueryItem] {
        switch self {
        case .googleBooksId(let googleBooksId): return [URLQueryItem(name: URLQueryItemKey.googleBooksId.rawValue, value: googleBooksId)]
        case .manualId(let manualId): return [URLQueryItem(name: URLQueryItemKey.manualBookId.rawValue, value: manualId)]
        case .isbn(let isbn): return [URLQueryItem(name: URLQueryItemKey.isbn.rawValue, value: isbn)]
        }
    }
}

private enum URLQueryItemKey: String {
    case googleBooksId = "gbid"
    case manualBookId = "mid"
    case isbn = "isbn"
    case addMethod = "method"
}

private enum AddMethod: String { //swiftlint:disable redundant_string_enum_value
    case manual = "manual"
    case search = "search"
    case barcode = "barcode"
}

private enum URLHost: String {
    case book = "book" //swiftlint:disable:this redundant_string_enum_value
}

private enum URLPath: String {
    case view = "/view"
    case editReadLog = "/edit-read-log"
    case add = "/add"
}

/// Handles app launch with a URL argument where the URL has scheme `readinglist://`
struct ProprietaryURLManager {
    static let scheme = "readinglist"

    func getURL(from action: ProprietaryURLAction) -> URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = action.host.rawValue
        components.path = action.path.rawValue
        components.queryItems = action.query
        guard let url = components.url else { preconditionFailure() }
        return url
    }

    func getAction(from url: URL) -> ProprietaryURLAction? {
        os_log("Handling URL: %{public}s", type: .default, url.absoluteString)
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            os_log("Invalid URL", type: .error)
            return nil
        }
        guard let urlHost = components.host, let host = URLHost(rawValue: urlHost) else {
            os_log("Unexpected URL Host", type: .error)
            return nil
        }

        // The "host" is the first part of the URL, which we use to identify the kind of resource we are accessing.
        switch host {
        case .book:
            return getBookAction(path: components.path, queryItems: components.queryItems)
        }
    }

    private func getBookAction(path urlPath: String, queryItems: [URLQueryItem]?) -> ProprietaryURLAction? {
        guard let path = URLPath(rawValue: urlPath) else {
            os_log("Unexpected URL Path", type: .error)
            return nil
        }
        switch path {
        case .view:
            guard let bookIdentifier = getBookIdentifier(from: queryItems) else { return nil }
            return .viewBook(id: bookIdentifier)
        case .add:
            return getAddMethod(from: queryItems)
        case .editReadLog:
            guard let bookIdentifier = getBookIdentifier(from: queryItems) else { return nil }
            return .editBookReadLog(id: bookIdentifier)
        }
    }

    private func getAddMethod(from queryItems: [URLQueryItem]?) -> ProprietaryURLAction? {
        guard let queryItems = queryItems else { return nil }
        guard let addMethod = queryItems.first(where: { $0.name == URLQueryItemKey.addMethod.rawValue })?.value else { return nil }
        guard let addMethodValue = AddMethod(rawValue: addMethod) else { return nil }
        switch addMethodValue {
        case .barcode: return .addBookScanBarcode
        case .manual: return .addBookManually
        case .search: return .addBookSearchOnline
        }
    }

    private func getBookIdentifier(from queryItems: [URLQueryItem]?) -> BookIdentifier? {
        guard let queryItems = queryItems else { return nil }
        if let googleBooksId = queryItems.first(where: { $0.name == URLQueryItemKey.googleBooksId.rawValue })?.value {
            return .googleBooksId(googleBooksId)
        } else if let isbn = queryItems.first(where: { $0.name == URLQueryItemKey.isbn.rawValue })?.value {
            return .isbn(isbn)
        } else if let manualId = queryItems.first(where: { $0.name == URLQueryItemKey.manualBookId.rawValue })?.value {
            return .manualId(manualId)
        } else {
            return nil
        }
    }
}
