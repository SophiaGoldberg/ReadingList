import Foundation
import SwiftUI
import WidgetKit

struct BookGrid: View {
    @Environment(\.widgetFamily) var size
    let books: [SharedBookData]

    private let urlManager = ProprietaryURLManager()
    private let booksPerRow = 4
    var rowCount: Int {
        if size == .systemLarge {
            return 2
        } else {
            return 1
        }
    }
    let rowSpacing: CGFloat = 16

    func maxRowHeight(_ geometryProxy: GeometryProxy) -> CGFloat {
        let rowHeightIncSpacing = geometryProxy.size.height / CGFloat(rowCount)
        return rowHeightIncSpacing - (CGFloat(rowCount - 1) * rowSpacing)
    }

    func imageHeight(_ geometryProxy: GeometryProxy) -> CGFloat {
        return min(maxRowHeight(geometryProxy) / 1.7, 100)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: rowSpacing) {
                ForEach(0..<rowCount) { row in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(0..<booksPerRow) { column in
                            if let book = books[safe: row * booksPerRow + column] {
                                // We need to pass in the desired image height so that BookDetails doesn't need to use
                                // a GeometryReader, which gobbles up all available height.
                                BookGridItem(bookData: book, imageHeight: imageHeight(geometry))
                                    // Put the padding here rather than spacing in the HStack, so we can correctly set the frame width to be
                                    // the correct proportion of the total width.
                                    .padding([.leading, .trailing], 8)
                                    .frame(
                                        width: geometry.size.width / CGFloat(booksPerRow),
                                        alignment: .top
                                    )
                                    .actionLink(.viewBook(id: book.id))
                            }
                        }
                    }.frame(maxHeight: maxRowHeight(geometry))
                }
            }
            // Expand the VStack to be full height and width of the frame, so that the books HStack
            // sits in the vertical center.
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
            // Push the full height VStack slightly up - it looks a bit nicer
            .offset(x: 0, y: -4)
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(Color(.secondarySystemBackground))
    }
}

struct BookGridItem: View {
    let bookData: SharedBookData
    let imageHeight: CGFloat

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Image(uiImage: bookData.coverUiImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: imageHeight)
                .cornerRadius(4, corners: .allCorners)
            Text(bookData.title)
                .font(.system(.caption2))
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .layoutPriority(-1) // Allow the text to be compressed in favour of the image / progress view.
            if let percentage = bookData.percentageComplete {
                ProgressDisplay(progressPercentage: percentage)
                    .actionLink(.editBookReadLog(id: bookData.id))
            }
        }
    }
}

struct BookGrid_Previews: PreviewProvider {
    static let data: [SharedBookData] = {
        let dataPath = Bundle.main.url(forResource: "shared_book_data", withExtension: "json")!
        return try! JSONDecoder().decode([SharedBookData].self, from: Data(contentsOf: dataPath))
    }()

    static var previews: some View {
        Group {
            BookGrid(books: data)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
            BookGrid(books: data)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}
