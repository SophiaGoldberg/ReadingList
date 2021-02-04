import Foundation
import SwiftUI
import CoreData
import ReadingList_Foundation

struct BookDetails: View {
    @ObservedObject var book: Book
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.presentationMode) var presentationMode
    @State var shareSheetPresented = false

    var descriptionLineCount: Int {
        if horizontalSizeClass == .regular && verticalSizeClass == .regular {
            return 8
        } else {
            return 4
        }
    }

    var body: some View {
        Group {
            if book.managedObjectContext == nil {
                EmptyView()
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        BookDetailsHeader(book: book)
                        Divider()
                        if let description = book.bookDescription {
                            if GeneralSettings.showExpandedDescription {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(Color(.secondaryLabel))
                            } else {
                                ExpandableText(description, lineLimit: descriptionLineCount, textStyle: .caption)
                                    .foregroundColor(Color(.secondaryLabel))
                            }
                            Divider()
                        }
                        AllBookMetadataView(book: book)
                    }.padding()
                }
            }
        }
    }
}

struct BookDetailsHeader: View {
    @ObservedObject var book: Book

    var titleFont: Font {
        if #available(iOS 14.0, *) {
            return .title2
        } else {
            return .title
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCover(coverImage: book.coverImage)
            VStack(alignment: .leading, spacing: 4) {
                Text(book.titleAndSubtitle)
                    .font(titleFont)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                    .background(GeometryReader { geometry in
                        Color.clear
                            .navigationBarTitle(
                                // Try to show the book's title in the navigation bar if the title
                                // has been scrolled enough. 60 is approx the height of the nav bar.
                                // Ideally we'd be able to ask "is this in view" instead.
                                geometry.frame(in: .global).maxY <= 60 + geometry.safeAreaInsets.top ? book.title : ""
                            )
                    })
                Text(book.authors.fullNames)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                ChangeReadStateButton(book: book)
                    .padding(.top, 6)
            }
            Spacer()
        }
    }
}

struct ChangeReadStateButton: View {
    @ObservedObject var book: Book

    func readStateButtonPressed() {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()
        guard book.readState == .toRead || book.readState == .reading else {
            assertionFailure("Change read state button pressed when not valid")
            return
        }

        if book.readState == .toRead {
            book.setReading(started: Date())
        } else if let started = book.startedReading {
            book.setFinished(started: started, finished: Date())
        }
        book.updateSortIndex()
        book.managedObjectContext!.saveAndLogIfErrored()
        feedbackGenerator.notificationOccurred(.success)

        UserEngagement.logEvent(.transitionReadState)

        // Only request a review if this was a Start tap: there have been a bunch of reviews
        // on the app store which are for books, not for the app!
        if book.readState == .reading {
            UserEngagement.onReviewTrigger()
        }
    }

    var body: some View {
        Group {
            if book.isFault {
                EmptyView()
            } else if book.readState == .toRead || book.readState == .reading {
                Button(action: {
                    withAnimation {
                        readStateButtonPressed()
                    }
                }) {
                    if book.readState == .toRead {
                        ChangeReadStateButtonView(text: "START", color: Color(.systemBlue))
                    } else {
                        ChangeReadStateButtonView(text: "FINISH", color: Color(.systemGreen))
                    }
                }
            }
        }
    }
}

struct ChangeReadStateButtonView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.body)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 15).foregroundColor(color)
            )
    }
}

struct BookCover: View {
    let coverImage: Data?

    var body: some View {
        Group {
            if let coverImage = coverImage, let uiImage = UIImage(data: coverImage) {
                Image(uiImage: uiImage)
                    .resizable()
                    .frame(width: 100, height: 150, alignment: .center)
                    .cornerRadius(5)
            } else {
                Image(systemName: "book")
                    .foregroundColor(Color(.systemGray))
                    .font(.title)
                    .frame(width: 100, height: 150, alignment: .center)
                    .background(Color(.systemGray5))
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.gray, lineWidth: 1)
                    )
            }
        }
    }
}

struct TableCellWidthEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var tableCellWidth: CGFloat {
        get {
            return self[TableCellWidthEnvironmentKey.self]
        }
        set {
            self[TableCellWidthEnvironmentKey.self] = newValue
        }
    }
}

struct TableCellWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat {
        if #available(iOS 14.0, *) {
            return 0
        } else {
            // iOS 13 has some issues with the use of preference values & environment to sync the
            // width of the left cells; instead, set a default value which is the calculated width
            // of the largest label on the page
            let constraintRect = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
            let boundingBox = "Publication Date".boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .footnote)], context: nil)
            return ceil(boundingBox.width)
        }
    }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct AllBookMetadataView: View {
    @ObservedObject var book: Book
    @State var labelWidth: CGFloat = {
        if #available(iOS 14.0, *) {
            // On iOS 14, start the width as wide as can be; it will be resized
            // down to the widest frames of the label texts.
            return .greatestFiniteMagnitude
        } else {
            // On iOS 13, we just calculate what we think the width is, and use that
            return TableCellWidthPreferenceKey.defaultValue
        }
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BookReadingLog(book: book)
            Divider()
            BookMetadataDetails(book: book)
            Divider()
            BookNotesSection(book: book)
            Divider()
            OrganizeSection(book: book)
            Spacer()
        }.onPreferenceChange(TableCellWidthPreferenceKey.self) {
            labelWidth = $0
        }
        .environment(\.tableCellWidth, labelWidth)
    }
}

struct DetailsTableRow<InnerView>: View where InnerView: View {
    let title: String
    let view: InnerView
    @Environment(\.tableCellWidth) var viewMaxWidth

    init(_ title: String, _ value: InnerView) {
        self.title = title
        self.view = value
    }

    init(_ title: String, _ value: String) where InnerView == Text {
        self.title = title
        self.view = Text(value)
            .font(.footnote)
            .foregroundColor(Color(.label))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.footnote)
                .foregroundColor(Color(.secondaryLabel))
                .background(GeometryReader { geometry in
                    Color.clear.preference(
                        key: TableCellWidthPreferenceKey.self,
                        value: geometry.size.width
                    )
                })
                .frame(width: viewMaxWidth, alignment: .trailing)
            view
        }
    }
}

struct TitledSection<HeaderButton, Details>: View where HeaderButton: View, Details: View {
    let header: String
    let button: HeaderButton
    let content: Details

    init(_ header: String, @ViewBuilder headerButtonBuilder: () -> HeaderButton, @ViewBuilder content: () -> Details) {
        self.header = header
        self.button = headerButtonBuilder()
        self.content = content()
    }

    init(_ header: String, headerButton: HeaderButton, @ViewBuilder content: () -> Details) {
        self.header = header
        self.button = headerButton
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(header)
                    .font(.system(.headline))
                Spacer()
                button
            }.padding(.bottom, 6)
            content.padding(.leading, 12)
        }
    }
}

struct BookReadingLog: View {
    @ObservedObject var book: Book

    func progressText() -> String? {
        switch book.progressAuthority {
        case .page:
            if let page = book.currentPage {
                if let percentage = book.currentPercentage {
                    return "Page \(page) (\(percentage)%)"
                } else {
                    return "Page \(page)"
                }
            } else {
                return nil
            }
        case .percentage:
            if let percent = book.currentPercentage {
                if let page = book.currentPage {
                    return "\(percent)% (page \(page))"
                } else {
                    return "\(percent)%"
                }
            } else {
                return nil
            }
        }
    }

    func readTimeText() -> String? {
        if book.readState == .toRead {
            return nil
        } else {
            let dayCount = NSCalendar.current.dateComponents([.day], from: book.startedReading!.startOfDay(), to: (book.finishedReading ?? Date()).startOfDay()).day ?? 0
            if dayCount <= 0 && book.readState == .finished {
                return "Within a day"
            } else if dayCount == 1 {
                return "1 day"
            } else {
                return "\(dayCount) days"
            }
        }
    }

    var body: some View {
        Group {
            if book.isFault {
                EmptyView()
            } else {
                TitledSection("Reading Log", headerButton: ModalPresentingButton("Update", presented: EditBookReadStateRepresentable(bookID: book.objectID))) {
                    DetailsTableRow("Read State", book.readState.description)
                    if let started = book.startedReading {
                        DetailsTableRow("Started", started.toPrettyString(short: false))
                    }
                    if let finished = book.finishedReading {
                        DetailsTableRow("Finished", finished.toPrettyString(short: false))
                    }
                    if let readTimeText = readTimeText() {
                        DetailsTableRow("Read Time", readTimeText)
                    }
                    if let progress = progressText() {
                        DetailsTableRow("Progress", progress)
                    }
                }
            }
        }
    }
}

struct AlertPresentingButton: View {
    @State var isPresented = false
    let text: String
    let alert: Alert

    var body: some View {
        Button(action: {
            isPresented = true
        }, label: {
            Text(text)
                .font(.headline)
                .alert(isPresented: $isPresented) {
                    alert
                }
        })
    }
}

struct ModalPresentingButton<ModalPresented>: View where ModalPresented: View {
    let text: String
    let modalPresented: ModalPresented
    @State var isPresented = false

    init(_ text: String, presented: ModalPresented) {
        self.text = text
        self.modalPresented = presented
    }

    init(_ text: String, @ViewBuilder presented: () -> ModalPresented) {
        self.text = text
        self.modalPresented = presented()
    }

    var body: some View {
        Button(action: {
            isPresented = true
        }, label: {
            Text(text)
                .font(.headline)
                .sheet(isPresented: $isPresented) {
                    modalPresented
                }
        })
    }
}

struct BookMetadataDetails: View {
    @ObservedObject var book: Book
    let amazonLinkBuilder = AmazonAffiliateLinkBuilder(locale: Locale.current)

    var amazonLink: URL? {
        guard let isbn = book.isbn13 else { return nil }
        return amazonLinkBuilder.buildAffiliateLink(fromIsbn13: isbn)
    }

    var googleLink: URL? {
        guard let googleBooksId = book.googleBooksId else { return nil }
        return GoogleBooksRequest.webpage(googleBooksId).url
    }

    var body: some View {
        Group {
            if book.isFault {
                EmptyView()
            } else {
                TitledSection("Details", headerButton: ModalPresentingButton("Edit", presented: EditBookMetadataRepresentable(config: .edit(book.objectID)))) {
                    if let isbn = book.isbn13 {
                        DetailsTableRow("ISBN", isbn.string)
                    }
                    if let pageCount = book.pageCount {
                        DetailsTableRow("Page Count", pageCount.string)
                    }
                    if let publicationDate = book.publicationDate {
                        DetailsTableRow("Publication Date", publicationDate.toPrettyString(short: false))
                    }
                    if !book.subjects.isEmpty {
                        DetailsTableRow("Subjects", book.subjects.map { $0.name }.sorted().joined(separator: ", "))
                    }
                    if let language = book.language {
                        DetailsTableRow("Language", language.description)
                    }
                    if let publisher = book.publisher {
                        DetailsTableRow("Publisher", publisher)
                    }
                    if googleLink != nil || amazonLink != nil {
                        DetailsTableRow("Find Online", VStack(alignment: .leading, spacing: 4) {
                            if let amazonLink = amazonLink {
                                SafariPresentingButton(amazonLink, buttonAction: {
                                    UserEngagement.logEvent(.viewOnAmazon)
                                }) {
                                    Text("Amazon\(amazonLinkBuilder.topLevelDomain)")
                                        .font(.footnote)
                                }
                            }
                            if let googleLink = googleLink {
                                SafariPresentingButton(googleLink) {
                                    Text("Google Books")
                                        .font(.footnote)
                                }
                            }
                        })
                    }
                }
            }
        }
    }
}

struct RatingView: View {
    let rating: Int16

    func starType(at index: Int) -> String {
        let ratingInt = Int(rating)
        if index < ratingInt / 2 {
            return "star.fill"
        } else if index == ratingInt / 2 && ratingInt % 2 != 0 {
            return "star.leadinghalf.fill"
        } else {
            return "star"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<5) { index in
                Image(systemName: starType(at: index))
                    .font(.system(size: 18))
                    .foregroundColor(Color(.systemOrange))
            }
        }
    }
}

struct BookNotesSection: View {
    @ObservedObject var book: Book
    @State var tableCellMaxWidth: CGFloat?

    var body: some View {
        Group {
            if book.isFault {
                EmptyView()
            } else {
                TitledSection("Notes", headerButton: ModalPresentingButton("Update", presented: EditBookNotesRepresentable(bookID: book.objectID))) {
                    if let rating = book.rating {
                        // The offset is a bit of hack to line up the stars
                        DetailsTableRow("Rating", RatingView(rating: rating).offset(x: 0, y: -4))
                    }
                    if let notes = book.notes {
                        Text(notes).font(.caption)
                    }
                    if book.rating == nil && book.notes == nil {
                        NoDataPlaceholder(text: "No Notes")
                    }
                }
            }
        }
    }
}

struct OrganizeSection: View {
    @ObservedObject var book: Book
    @State var tableCellMaxWidth: CGFloat?

    var body: some View {
        Group {
            if book.isFault {
                EmptyView()
            } else {
                TitledSection("Organise", headerButtonBuilder: {
                    ModalPresentingButton("Manage Lists") {
                        ManageListsRepresentable(book: book) {
                            UserEngagement.logEvent(.addBookToList)
                            UserEngagement.onReviewTrigger()
                        }
                    }
                }) {
                    if !book.lists.isEmpty {
                        DetailsTableRow("Lists", VStack(alignment: .leading, spacing: 4) {
                            ForEach(book.lists.map { $0.name }, id: \.self) {
                                Text($0)
                                    .font(.footnote)
                                    .foregroundColor(Color(.label))
                            }
                        })
                    } else {
                        NoDataPlaceholder(text: "No Lists")
                    }
                }
            }
        }
    }
}

struct NoDataPlaceholder: View {
    let text: String

    var body: some View {
        HStack {
            Spacer()
            Text(text)
                .font(.footnote)
                .foregroundColor(Color(.secondaryLabel))
            Spacer()
        }.padding(.vertical, 4)
    }
}

struct BookDetails_Previews: PreviewProvider {
    static var testBook: Book = {
        let book = Book(context: PersistentStoreManager.container.viewContext)
        book.title = "Test Title Which Is Really Long"
        book.bookDescription = "Here is a test book with a description which is fairly long, long enough to cause the text to wrap over multiple lines which will then require a button to be able to view the full description. Here is a test book with a description which is fairly long, long enough to cause the text to wrap over multiple lines which will then require a button to be able to view the full description."
        book.subtitle = "A Novel"
        book.authors = [
            Author(lastName: "Bennet", firstNames: "Andrew"),
            Author(lastName: "Smith", firstNames: "John"),
            Author(lastName: "Else", firstNames: "Someone")
        ]
        book.setReading(started: Date())
        book.pageCount = 132
        book.setProgress(.page(31))
        book.language = .en
        book.isbn13 = 9783161484100
        book.publisher = "Penguin Books"
        book.googleBooksId = "a74ydshca8"
        book.rating = 7
        book.notes = "I liked this book"
        book.subjects = [
            Subject(context: PersistentStoreManager.container.viewContext, name: "Fiction"),
            Subject(context: PersistentStoreManager.container.viewContext, name: "Science")
        ]
        let list1 = List(context: PersistentStoreManager.container.viewContext, name: "Fiction")
        let list2 = List(context: PersistentStoreManager.container.viewContext, name: "Science Fiction")
        let list3 = List(context: PersistentStoreManager.container.viewContext, name: "Wish List")
        list1.addBooks([book])
        list2.addBooks([book])
        list3.addBooks([book])
        return book
    }()

    static var previews: some View {
        NavigationView {
            BookDetails(book: testBook)
        }
    }
}
