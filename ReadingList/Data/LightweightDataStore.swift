import Foundation
import PersistedPropertyWrapper
import ReadingList_Foundation

struct LightweightDataStore {
    private init() {}

    /// This is not always true; tip functionality predates this setting...
    @Persisted("hasEverTipped", defaultValue: false)
    static var hasEverTipped: Bool

    @Persisted("lastSelectedLanguage")
    static var lastSelectedLanguage: LanguageIso639_1?
}
