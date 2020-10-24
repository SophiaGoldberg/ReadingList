import Foundation
import CHCSVParser

public protocol CSVParserDelegate: class {
    func headersRead(_ headers: [String]) -> Bool
    func lineParseSuccess(_ values: [String: String])
    func lineParseError()
    func onFailure(_ error: CSVImportError)
    func completion()
}

public enum CSVImportError: Error {
    case invalidCsv
    case missingHeaders
}

public class CSVParser: NSObject, CHCSVParserDelegate {

    // CHCSVParserDelegate is informed of each read field. This wrapper is intended to create a simpler CSV Parser
    // which can response to completed lines, by the header names.
    private let parser: CHCSVParser!

    public init(csvFileUrl: URL) {
        parser = CHCSVParser(contentsOfCSVURL: csvFileUrl)
        parser.sanitizesFields = true
        parser.trimsWhitespace = true
        parser.recognizesComments = true
        super.init()
        parser.delegate = self
    }

    public var delegate: CSVParserDelegate? //swiftlint:disable:this weak_delegate
                                            // (weakness not required in pratice)

    public func begin() { parser.parse() }
    public func stop() { parser.cancelParsing() }

    private var isFirstRow = true
    private var currentRowIsErrored = false
    private var currentRow = [String: String]()
    private var headersByFieldIndex = [Int: String]()

    public func parser(_ parser: CHCSVParser!, didBeginLine recordNumber: UInt) {
        currentRow.removeAll(keepingCapacity: true)
        currentRowIsErrored = false
    }

    public func parser(_ parser: CHCSVParser!, didReadField field: String!, at fieldIndex: Int) {
        guard !isFirstRow else { headersByFieldIndex[fieldIndex] = field; return }
        guard let currentHeader = headersByFieldIndex[fieldIndex] else { currentRowIsErrored = true; return }
        if let fieldValue = field.trimming().nilIfWhitespace() {
            currentRow[currentHeader] = fieldValue
        }
    }

    public func parser(_ parser: CHCSVParser!, didFailWithError error: Error!) {
        delegate?.onFailure(.invalidCsv)
    }

    public func parser(_ parser: CHCSVParser!, didEndLine recordNumber: UInt) {
        if isFirstRow {
            if delegate?.headersRead(headersByFieldIndex.map { $0.value }) == false {
                stop()
                delegate?.onFailure(.missingHeaders)
                delegate = nil // Remove the delegate to stop any further callbacks
            } else {
                isFirstRow = false
            }
            return
        }

        guard !currentRowIsErrored else { delegate?.lineParseError(); return }
        delegate?.lineParseSuccess(currentRow)
    }

    public func parserDidEndDocument(_ parser: CHCSVParser!) {
        delegate?.completion()
    }
}
