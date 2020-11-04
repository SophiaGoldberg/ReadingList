import WidgetKit
import SwiftUI

struct EmptyEntry: TimelineEntry {
    let date: Date
}

struct EmptyTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> EmptyEntry {
        EmptyEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (EmptyEntry) -> Void) {
        completion(EmptyEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let timeline = Timeline(entries: [EmptyEntry(date: Date())], policy: .never)
        completion(timeline)
    }
}

struct AddBooksWidget: Widget {
    let kind = "com.andrewbennet.books.add-books"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EmptyTimelineProvider()) { _ in
            AddBooksView()
        }
        .configurationDisplayName("Add Books")
        .description("Quick shortcuts to add new books to Reading List.")
        .supportedFamilies([.systemMedium])
    }
}

struct AddBooksSingleMethodWidgetView: View {
    let mode: AddBookMode
    var body: some View {
        AddBookSingleMethodView(mode: mode)
            .widgetURL(for: mode.action)
    }
}

struct SearchOnlineWidget: Widget {
    let kind = "com.andrewbennet.books.search-online"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EmptyTimelineProvider()) { _ in
            AddBooksSingleMethodWidgetView(mode: .searchOnline)
        }
        .configurationDisplayName("Search Online")
        .description("Quick shortcuts to add new books to Reading List.")
        .supportedFamilies([.systemSmall])
    }
}

struct ScanBarcodeWidget: Widget {
    let kind = "com.andrewbennet.books.scan-barcode"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EmptyTimelineProvider()) { _ in
            AddBooksSingleMethodWidgetView(mode: .scanBarcode)
        }
        .configurationDisplayName("Scan Barcode")
        .description("Quick shortcuts to add new books to Reading List.")
        .supportedFamilies([.systemSmall])
    }
}
