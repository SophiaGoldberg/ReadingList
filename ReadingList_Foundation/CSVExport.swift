import Foundation
import os.log

public protocol CsvColumn {
    associatedtype Data
    var header: String { get }
    func cellValue(_: Data) -> String?
}

public struct CsvExport<Column> where Column: CsvColumn {
    public let columns: [Column]

    public init(columns: [Column]) {
        self.columns = columns
    }

    func headers() -> [String] {
        return columns.map { $0.header }
    }

    func cellValues(data: Column.Data) -> [String] {
        return columns.map { $0.cellValue(data) ?? "" }
    }
}

public class CsvExporter<Column> where Column: CsvColumn {
    let csvExport: CsvExport<Column>
    let filePath: URL
    let temporaryFilePath = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString)
    private var fileBuffer: String

    public init(filePath: URL, csvExport: CsvExport<Column>) {
        self.csvExport = csvExport
        self.filePath = filePath
        fileBuffer = CsvExporter.convertToCsvLine(csvExport.headers())
    }

    public func addData(_ dataArray: [Column.Data]) {
        for data in dataArray {
            addData(data)
        }
        flush()

        // Remove existing file if present
        os_log("Moving temporary file at %{public}s to %{public}s", type: .info, temporaryFilePath.path, filePath.path)
        try? FileManager.default.removeItem(at: filePath)
        try! FileManager.default.moveItem(at: temporaryFilePath, to: filePath)
    }

    public func addData(_ data: Column.Data) {
        fileBuffer.append(CsvExporter.convertToCsvLine(csvExport.cellValues(data: data)))
        // flush to file every 1MB
        if fileBuffer.utf8.count > 1048576 {
            flush()
        }
    }

    private func flush() {
        os_log("Flushing export from memory to temporary file", type: .debug)
        try! fileBuffer.append(toFile: temporaryFilePath, encoding: .utf8)
        fileBuffer = ""
    }

    private static func convertToCsvLine(_ cellValues: [String]) -> String {
        return cellValues.map { cellValue in
            let charactersWhichRequireWrapping = CharacterSet(charactersIn: "\n,\"")
            let wrapInQuotes = cellValue.rangeOfCharacter(from: charactersWhichRequireWrapping) != nil

            // Replace " with ""
            let escapedString = cellValue.replacingOccurrences(of: "\"", with: "\"\"")

            if wrapInQuotes {
                return "\"\(escapedString)\""
            }
            return escapedString
        }.joined(separator: ",") + "\n"
    }
}
