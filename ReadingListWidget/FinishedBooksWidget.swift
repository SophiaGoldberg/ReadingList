import WidgetKit
import SwiftUI

struct BookTimelineFinishedBooksProvider: TimelineProvider {
    func placeholder(in context: Context) -> BooksEntry {
        BooksEntry(date: Date(), books: SharedBookData.finishedBooks)
    }

    func getSnapshot(in context: Context, completion: @escaping (BooksEntry) -> Void) {
        completion(BooksEntry(date: Date(), books: SharedBookData.finishedBooks))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = BooksEntry(date: Date(), books: SharedBookData.finishedBooks)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct ReadingListFinishedBooksWidget: Widget {
    let kind = WidgetKind.finishedBooks

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BookTimelineFinishedBooksProvider()) { entry in
            ReadingListBooksView(books: entry.books, type: .finished, entryDate: entry.date)
        }
        .configurationDisplayName("Finished Books")
        .description("An overview of your recently finished books.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
