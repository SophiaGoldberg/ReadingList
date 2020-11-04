import Foundation
import StoreKit
import Firebase
import FirebaseCrashlytics
import PersistedPropertyWrapper
import ReadingList_Foundation

class UserEngagement {

    static var defaultAnalyticsEnabledValue: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }

    @Persisted("sendAnalytics", defaultValue: defaultAnalyticsEnabledValue)
    static var sendAnalytics: Bool

    @Persisted("sendCrashReports", defaultValue: defaultAnalyticsEnabledValue)
    static var sendCrashReports: Bool

    static func initialiseUserAnalytics() {
        guard BuildInfo.thisBuild.type == .testFlight || sendAnalytics || sendCrashReports else { return }

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        let enableCrashlyticsReporting = BuildInfo.thisBuild.type == .testFlight || sendCrashReports
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enableCrashlyticsReporting)

        let enableAnalyticsCollection = BuildInfo.thisBuild.type == .testFlight || sendAnalytics
        Analytics.setAnalyticsCollectionEnabled(enableAnalyticsCollection)
    }

    @Persisted("userEngagementCount", defaultValue: 0)
    static var userEngagementCount: Int

    private static func shouldTryRequestReview() -> Bool {
        let appStartCountMinRequirement = 3
        let userEngagementModulo = 10
        return AppLaunchHistory.appOpenedCount >= appStartCountMinRequirement && userEngagementCount % userEngagementModulo == 0
    }

    static func onReviewTrigger() {
        userEngagementCount += 1
        if shouldTryRequestReview() {
            SKStoreReviewController.requestReview()
        }
    }

    enum Event: String {
        // Add books
        case searchOnline = "Search_Online"
        case scanBarcode = "Scan_Barcode"
        case scanBarcodeBulk = "Scan_Barcode_Bulk"
        case searchOnlineMultiple = "Search_Online_Multiple"
        case addManualBook = "Add_Manual_Book"
        case searchForExistingBookByIsbn = "Search_For_Existing_Book_By_ISBN"

        // Data
        case csvImport = "CSV_Import"
        case csvGoodReadsImport = "CSV_Import_Goodreads"
        case csvExport = "CSV_Export"
        case deleteAllData = "Delete_All_Data"

        // Navigation
        case searchLibrary = "Search_Library"
        case searchLibrarySwitchScope = "Search_Library_Switch_Scope"

        // Modify books
        case transitionReadState = "Transition_Read_State"
        case bulkEditReadState = "Bulk_Edit_Read_State"
        case deleteBook = "Delete_Book"
        case bulkDeleteBook = "Bulk_Delete_Book"
        case editBook = "Edit_Book"
        case updateBookFromGoogle = "Update_Book_From_Google"
        case editReadState = "Edit_Read_State"
        case changeSortOrder = "Change_Sort"
        case moveBookToTop = "Move_Book_To_Top"
        case moveBookToBottom = "Move_Book_To_Bottom"

        // Lists
        case createList = "Create_List"
        case addBookToList = "Add_Book_To_List"
        case bulkAddBookToList = "Bulk_Add_Book_To_List"
        case removeBookFromList = "Remove_Book_From_List"
        case reorderList = "Reorder_List"
        case deleteList = "Delete_List"
        case changeListSortOrder = "Change_List_Sort_Order"
        case renameList = "Rename_List"

        // Quick actions
        case searchOnlineQuickAction = "Quick_Action_Search_Online"
        case scanBarcodeQuickAction = "Quick_Action_Scan_Barcode"

        // Proprietary URL launch
        case openBookFromUrl = "Open_Book_From_Url"
        case openEditReadLogFromUrl = "Open_Edit_Read_Log_From_Url"
        case openSearchOnlineFromUrl = "Open_Search_Online_From_Url"
        case openScanBarcodeFromUrl = "Open_Scan_Barcode_From_Url"
        case openAddManuallyFromUrl = "Open_Add_Manually_From_Url"

        // Settings changes
        case disableAnalytics = "Disable_Analytics"
        case enableAnalytics = "Enable_Analytics"
        case disableCrashReports = "Disable_Crash_Reports"
        case enableCrashReports = "Enable_Crash_Reports"
        case changeTheme = "Change_Theme"
        case changeSearchOnlineLanguage = "Change_Search_Online_Language"
        case changeCsvImportFormat = "Change_CSV_Import_Format"
        case changeCsvImportSettings = "Change_CSV_Import_Settings"

        // Other
        case viewOnAmazon = "View_On_Amazon"
        case openCsvInApp = "Open_CSV_In_App"
    }

    static func logEvent(_ event: Event) {
        // Note: TestFlight users are automatically enrolled in analytics reporting. This should be reflected
        // on the corresponding Settings page.
        guard BuildInfo.thisBuild.type == .testFlight || sendAnalytics else { return }
        #if RELEASE
        Analytics.logEvent(event.rawValue, parameters: nil)
        #endif
    }

    static func logError(_ error: Error) {
        // Note: TestFlight users are automatically enrolled in crash reporting. This should be reflected
        // on the corresponding Settings page.
        guard BuildInfo.thisBuild.type == .testFlight || sendCrashReports else { return }
        Crashlytics.crashlytics().record(error: error)
    }
}
