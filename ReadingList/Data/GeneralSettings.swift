import ReadingList_Foundation
import PersistedPropertyWrapper

struct GeneralSettings {
    private init() { }

    @Persisted("searchLanguageRestriction")
    static var searchLanguageRestriction: LanguageIso639_1?

    @Persisted("prepopulateLastLanguageSelection", defaultValue: true)
    static var prepopulateLastLanguageSelection: Bool

    @Persisted("showExpandedDescription", defaultValue: false)
    static var showExpandedDescription: Bool

    @Persisted("defaultProgressType", defaultValue: .page)
    static var defaultProgressType: ProgressType

    @Persisted("addCustomBooksToTopOfCustom", defaultValue: false)
    static var addBooksToTopOfCustom: Bool

    @available(iOS, obsoleted: 13.0)
    @Persisted("theme", defaultValue: .normal)
    static var theme: Theme
}
