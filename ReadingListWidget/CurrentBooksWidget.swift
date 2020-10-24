import WidgetKit
import SwiftUI

struct BookTimelineCurrentBooksProvider: TimelineProvider {
    func placeholder(in context: Context) -> BooksEntry {
        BooksEntry(date: Date(), books: SharedBookData.currentBooks)
    }

    func getSnapshot(in context: Context, completion: @escaping (BooksEntry) -> Void) {
        completion(BooksEntry(date: Date(), books: SharedBookData.currentBooks))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let startOfToday = Date().start
        // Let's get a week's worth of entries
        let entries = (0..<7).map { index in
            BooksEntry(date: startOfToday.addingDays(index), books: SharedBookData.currentBooks)
        }
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct ReadingListCurrentBooksWidget: Widget {
    let kind = WidgetKind.currentBooks

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BookTimelineCurrentBooksProvider()) { entry in
            ReadingListBooksView(books: entry.books, type: .current, entryDate: entry.date)
        }
        .configurationDisplayName("Current Books")
        .description("Quick access to the books are you reading or are next in your To Read list.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
