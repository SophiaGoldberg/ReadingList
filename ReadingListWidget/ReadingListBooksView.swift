import SwiftUI
import WidgetKit

struct ReadingListBooksView: View {
    @Environment(\.widgetFamily) var size: WidgetFamily
    let books: [SharedBookData]
    let type: BookViewType
    let entryDate: Date

    var body: some View {
        if books.isEmpty {
            NoBooksView(type: type)
        } else if size == .systemSmall {
            SingleBookView(book: books[0], entryDate: entryDate)
        } else {
            BookGrid(books: books)
        }
    }
}
