import Foundation
import CoreData
import ReadingList_Foundation
import os.log

@objc(Book)
class Book: NSManagedObject {

    /**
     The read state of a book is determined by the presence or absence of the startedReading and finishedReading
     dates. It exists as a core data attribute primarily to allow its use as a section keypath.
     */
    @NSManaged private(set) var readState: BookReadState
    @NSManaged private(set) var startedReading: Date?
    @NSManaged private(set) var finishedReading: Date?

    /// Whether the last set read progress was set by a page number or by percentage
    @NSManaged private(set) var currentProgressIsPage: Bool
    @NSManaged var sort: Int32

    @NSManaged var googleBooksId: String?
    @NSManaged var manualBookId: String?
    @NSManaged var title: String

    /// Whether the subtitle field has a non-nil value. Used for sorting purposes.
    @NSManaged private(set) var hasSubtitle: Bool

    @NSManaged private(set) var authorSort: String
    @NSManaged var publicationDate: Date?
    @NSManaged var publisher: String?
    @NSManaged var bookDescription: String?
    @NSManaged var coverImage: Data?
    @NSManaged var notes: String?
    @NSManaged var subjects: Set<Subject>
    @NSManaged private(set) var addedWhen: Date?

    @NSManaged private(set) var listItems: Set<ListItem>
    var lists: [List] {
        listItems.map(\.list)
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()
        addedWhen = Date()
    }

    func setToRead() {
        readState = .toRead
        startedReading = nil
        finishedReading = nil
        currentPage = nil
        currentPercentage = nil
    }

    func setReading(started: Date) {
        readState = .reading
        startedReading = started
        finishedReading = nil
    }

    func setFinished(started: Date, finished: Date) {
        readState = .finished
        startedReading = started
        if finished >= started {
            finishedReading = finished
        } else {
            finishedReading = started
        }
        currentPage = nil
        currentPercentage = nil
    }

    func setDefaultReadDates(for readState: BookReadState) {
        switch readState {
        case .toRead: setToRead()
        case .reading: setReading(started: Date())
        case .finished: setFinished(started: Date(), finished: Date())
        }
    }

    func setProgress(_ progress: Progress?) {
        guard let progress = progress else {
            currentPage = nil
            currentPercentage = nil
            return
        }
        switch progress {
        case .page(let newPageNumber):
            progressAuthority = .page
            if let newPageNumber = newPageNumber {
                currentPage = max(0, newPageNumber)
            } else {
                currentPage = nil
            }
        case .percentage(let newPercentage):
            progressAuthority = .percentage
            if let newPercentage = newPercentage {
                currentPercentage = max(0, min(100, newPercentage))
            } else {
                currentPercentage = nil
            }
        }

        updateComputedProgressData()
    }

    private func updateComputedProgressData() {
        if currentProgressIsPage {
            if let pageCount = pageCount, let currentPage = currentPage, pageCount != 0 {
                if let calculatedPercentage = Int32(exactly: round((Float(currentPage) / Float(pageCount)) * 100)) {
                    currentPercentage = min(100, calculatedPercentage)
                } else {
                    currentPercentage = 100
                }
            } else {
                currentPercentage = nil
            }
        } else {
            if let pageCount = pageCount, let currentPercentage = currentPercentage {
                currentPage = Int32(round(Float(pageCount) * (Float(currentPercentage) / 100)))
            } else {
                currentPage = nil
            }
        }
    }

    private(set) var progressAuthority: ProgressType {
        get { return currentProgressIsPage ? .page : .percentage }
        set { currentProgressIsPage = newValue == .page }
    }

    /**
     Enumerates the attributes which are not represented as standard NSManaged variables. These are usually
     the optional numerical attributes, which are much more convenient to use when handled manually in their
     Swift types, than represented as @NSManaged optional NSNumber objects.
    */
    enum Key: String { //swiftlint:disable redundant_string_enum_value
        case authors = "authors"
        case isbn13 = "isbn13"
        case pageCount = "pageCount"
        case currentPage = "currentPage"
        case currentPercentage = "currentPercentage"
        case rating = "rating"
        case languageCode = "languageCode"
        case subtitle = "subtitle"
    } //swiftlint:enable redundant_string_enum_value

    private func safelyGetPrimitiveValue(_ key: Book.Key) -> Any? {
        return safelyGetPrimitiveValue(forKey: key.rawValue)
    }

    private func safelySetPrimitiveValue(_ value: Any?, _ key: Book.Key) {
        return safelySetPrimitiveValue(value, forKey: key.rawValue)
    }

    // The following variables are manually managed rather than using @NSManaged, to allow non-objc types
    // to be used, or to allow us to hook into the setter, to update other properties automatically.

    @objc var authors: [Author] {
        get { return (safelyGetPrimitiveValue(forKey: #keyPath(Book.authors)) as! [Author]?) ?? [] }
        set {
            safelySetPrimitiveValue(newValue, forKey: #keyPath(Book.authors))
            authorSort = newValue.lastNamesSort
        }
    }

    @objc var subtitle: String? {
        get { return safelyGetPrimitiveValue(.subtitle) as! String? }
        set {
            safelySetPrimitiveValue(newValue, .subtitle)
            hasSubtitle = newValue != nil
        }
    }

    var isbn13: Int64? {
        get { return safelyGetPrimitiveValue(.isbn13) as! Int64? }
        set { safelySetPrimitiveValue(newValue, .isbn13) }
    }

    var pageCount: Int32? {
        get { return safelyGetPrimitiveValue(.pageCount) as! Int32? }
        set {
            safelySetPrimitiveValue(newValue, .pageCount)
            updateComputedProgressData()
        }
    }

    private(set) var currentPage: Int32? {
        get { return safelyGetPrimitiveValue(.currentPage) as! Int32? }
        set { safelySetPrimitiveValue(newValue, .currentPage) }
    }

    private(set) var currentPercentage: Int32? {
        get { return safelyGetPrimitiveValue(.currentPercentage) as! Int32? }
        set { safelySetPrimitiveValue(newValue, .currentPercentage) }
    }

    /// A rating out of 10
    var rating: Int16? {
        get { return safelyGetPrimitiveValue(.rating) as! Int16? }
        set { safelySetPrimitiveValue(newValue, .rating) }
    }

    var language: LanguageIso639_1? {
        get {
            if let code = safelyGetPrimitiveValue(.languageCode) as! String? {
                return LanguageIso639_1(rawValue: code)
            } else {
                return nil
            }
        }
        set { safelySetPrimitiveValue(newValue?.rawValue, .languageCode) }
    }

    func updateSortIndex() {
        sort = BookSortIndexManager(context: managedObjectContext!, readState: readState, exclude: self).getAndIncrementSort()
    }

    override func prepareForDeletion() {
        super.prepareForDeletion()
        for subject in subjects where subject.books.count == 1 {
            subject.delete()
            os_log("Orphaned subject %{public}s deleted.", type: .info, subject.name)
        }
    }
}

extension Book {

    var titleAndSubtitle: String {
        if let subtitle = subtitle {
            return "\(title): \(subtitle)"
        } else {
            return title
        }
    }

    func set<T>(_ key: ReferenceWritableKeyPath<Book, T?>, ifNotNil value: T?) {
        if let value = value {
            self[keyPath: key] = value
        }
    }

    func populate(fromFetchResult fetchResult: GoogleBooksApi.FetchResult) {
        googleBooksId = fetchResult.id
        title = fetchResult.title
        if !fetchResult.authors.isEmpty {
            authors = fetchResult.authors.map(Author.init(firstNameLastName:))
        }
        set(\.subtitle, ifNotNil: fetchResult.subtitle)
        set(\.bookDescription, ifNotNil: fetchResult.description)
        subjects.formUnion(fetchResult.subjects.map { Subject.getOrCreate(inContext: self.managedObjectContext!, withName: $0) })
        set(\.coverImage, ifNotNil: fetchResult.image)
        set(\.pageCount, ifNotNil: fetchResult.pageCount?.int32)
        set(\.publisher, ifNotNil: fetchResult.publisher)
        set(\.isbn13, ifNotNil: fetchResult.isbn13?.int)
        set(\.language, ifNotNil: fetchResult.language)
    }

    func populate(fromCsvRow values: BookCSVImportRow) {
        title = values.title
        authors = values.authors

        set(\.subtitle, ifNotNil: values.subtitle)
        set(\.googleBooksId, ifNotNil: values.googleBooksId)
        set(\.isbn13, ifNotNil: values.isbn13?.int)
        if googleBooksId == nil && manualBookId == nil {
            manualBookId = values.manualBookId ?? UUID().uuidString
        }
        set(\.pageCount, ifNotNil: values.pageCount)
        if let page = values.currentPage {
            setProgress(.page(page))
        } else if let percentage = values.currentPercentage {
            setProgress(.percentage(percentage))
        }
        set(\.notes, ifNotNil: values.notes?.replacingOccurrences(of: "\r\n", with: "\n"))
        set(\.publicationDate, ifNotNil: values.publicationDate)
        set(\.publisher, ifNotNil: values.publisher)
        set(\.bookDescription, ifNotNil: values.description?.replacingOccurrences(of: "\r\n", with: "\n"))
        if let started = values.started {
            if let finished = values.finished {
                setFinished(started: started, finished: finished)
            } else {
                setReading(started: started)
            }
        }

        if let rating = values.rating, let integerRating = Int16(exactly: rating * 2), integerRating > 0 && integerRating <= 10 {
            self.rating = integerRating
        }
        if let language = values.language {
            set(\.language, ifNotNil: LanguageIso639_1(rawValue: language))
        }
    }

    static func get(fromContext context: NSManagedObjectContext, googleBooksId: String? = nil, isbn: String? = nil, manualBookId: String? = nil) -> Book? {
        let fetchRequest = NSManagedObject.fetchRequest(Book.self, limit: 1)
        fetchRequest.returnsObjectsAsFaults = false

        // Collect the predicates which we apply (OR'd) to our fetch request
        var predicates = [NSPredicate]()
        if let googleBooksId = googleBooksId {
            predicates.append(NSPredicate(format: "%K == %@", #keyPath(Book.googleBooksId), googleBooksId))
        }
        if let isbn = isbn {
            predicates.append(NSPredicate(format: "%K == %@", Book.Key.isbn13.rawValue, isbn))
        }
        if let manualBookId = manualBookId {
            predicates.append(NSPredicate(format: "%K == %@", #keyPath(Book.manualBookId), manualBookId))
        }

        guard !predicates.isEmpty else { return nil }
        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)

        return (try! context.fetch(fetchRequest)).first
    }

    /**
     Gets the "maximal" sort value of any book - i.e. either the maximum or minimum value.
    */
    private static func maximalSort(getMax: Bool, with readState: BookReadState, from context: NSManagedObjectContext, excluding excludedBook: Book?) -> Int32? {
        // The following code could (and in fact was) rewritten to use an NSExpression to just grab the max or min
        // sort, but it crashes when the store type is InMemoryStore (as it is in tests). Would need to rewrite
        // the unit tests to use SQL stores. See https://stackoverflow.com/a/13681549/5513562
        let fetchRequest = NSManagedObject.fetchRequest(Book.self, limit: 1)
        let readStatePredicate = NSPredicate(format: "%K == %ld", #keyPath(Book.readState), readState.rawValue)
        if let excludedBook = excludedBook {
            fetchRequest.predicate = .and([readStatePredicate, NSPredicate(format: "SELF != %@", excludedBook)])
        } else {
            fetchRequest.predicate = readStatePredicate
        }
        fetchRequest.sortDescriptors = [NSSortDescriptor(\Book.sort, ascending: !getMax)]
        fetchRequest.returnsObjectsAsFaults = false
        return (try! context.fetch(fetchRequest)).first?.sort
    }

    static func maxSort(with readState: BookReadState, from context: NSManagedObjectContext, excluding excludedBook: Book? = nil) -> Int32? {
        return maximalSort(getMax: true, with: readState, from: context, excluding: excludedBook)
    }

    static func minSort(with readState: BookReadState, from context: NSManagedObjectContext, excluding excludedBook: Book? = nil) -> Int32? {
        return maximalSort(getMax: false, with: readState, from: context, excluding: excludedBook)
    }
}
