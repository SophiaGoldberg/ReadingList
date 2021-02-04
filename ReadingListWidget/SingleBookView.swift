import Foundation
import SwiftUI
import WidgetKit

struct SingleBookView: View {
    let book: SharedBookData
    let entryDate: Date

    var daysSinceStarted: Int? {
        guard let daysBetween = book.startDate?.daysUntil(entryDate), daysBetween >= 0 else {
            return nil
        }
        return daysBetween
    }

    func daysText(number dayCount: Int) -> String? {
        guard dayCount > 0 else { return nil }
        return "\(dayCount) day\(dayCount == 1 ? "" : "s")"
    }

    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    var body: some View {
        GeometryReader { geometryProxy in
            VStack(alignment: .center) {
                HStack(alignment: .top, spacing: 8) {
                    Image(uiImage: book.coverUiImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometryProxy.size.width / 3, alignment: .leading)
                        .cornerRadius(6)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.system(size: 13))
                            .fontWeight(.medium)
                            .allowsTightening(true)
                        Text(book.authorDisplay)
                            .font(.system(size: 12))
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 2) {
                    if let progress = book.percentageComplete {
                        ProgressBar(currentProgress: CGFloat(progress) / 100)
                            .frame(height: 2)
                        HStack {
                            Text("\(progress)%")
                            Spacer()
                            if let started = book.startDate, let text = daysText(number: started.daysUntil(entryDate)) {
                                Text(text)
                            }
                        }
                    } else if let started = book.startDate {
                        HStack {
                            if let finished = book.finishDate, let text = daysText(number: started.daysUntil(finished)) {
                                Text(dateFormatter.string(from: finished))
                                Spacer()
                                Text(text)
                            } else if let text = daysText(number: started.daysUntil(entryDate)) {
                                Text(text)
                                Spacer()
                            }
                        }.padding([.leading, .trailing], 4)
                    }
                }
                .foregroundColor(.secondary)
                .font(.system(size: 11))
                .padding([.leading, .trailing], 4)
            }
            .padding([.top, .bottom], 16)
            .padding([.leading, .trailing], 8)
            // If we didn't have anything to show under the main portion of the view,
            // bump the view up a little bit
            .offset(x: 0, y: book.percentageComplete == nil && book.startDate == nil && book.finishDate == nil ? -8 : 0)
            .frame(maxHeight: .infinity, alignment: .center)
            .widgetURL(for: book.percentageComplete == nil ? .viewBook(id: book.id) : .editBookReadLog(id: book.id))
        }
    }
}

struct SingleBook_Previews: PreviewProvider {
    static let currentBooks = Bundle.main.decodedData(
        as: [SharedBookData].self,
        jsonFileName: "shared_current-books"
    )
    static let finishedBooks = Bundle.main.decodedData(
        as: [SharedBookData].self,
        jsonFileName: "shared_finished-books"
    )

    static var previews: some View {
        Group {
            ForEach(currentBooks + finishedBooks) {
                SingleBookView(book: $0, entryDate: Date())
                    .previewContext(WidgetPreviewContext(family: .systemSmall))
            }
        }
    }
}
