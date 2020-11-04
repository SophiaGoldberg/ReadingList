import Foundation
import UIKit
import Eureka
import ReadingList_Foundation

final class General: FormViewController {
    override func viewDidLoad() {
        if #available(iOS 13.0, *) {
            initialiseInsetGroupedTable()
        }

        super.viewDidLoad()

        form +++ Section(header: "Appearance", footer: "Enable Expanded Descriptions to automatically show each book's full description.")
            <<< SwitchRow {
                $0.title = "Expanded Descriptions"
                $0.value = GeneralSettings.showExpandedDescription
                $0.onChange { row in
                    guard let newValue = row.value else { return }
                    GeneralSettings.showExpandedDescription = newValue
                }
            }

        if #available(iOS 13.0, *) {} else {
            form.allSections[0] <<< ThemedPushRow<Theme> {
                $0.title = "Theme"
                $0.options = Theme.allCases
                $0.value = GeneralSettings.theme
                $0.onChange { row in
                    guard let theme = row.value else { return }
                    // Half a second seems long enough for the animation to have completed; if we change the theme while
                    // the animation is still running, we get stuck with an incorrect coloured navigation item. Could
                    // not find a workaround, so settled for a slightly longer delay before theme transition.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        GeneralSettings.theme = theme
                        NotificationCenter.default.post(name: .ThemeSettingChanged, object: nil)
                        UserEngagement.logEvent(.changeTheme)
                    }
                }
            }
        }

        form +++ Section(header: "Progress", footer: "Choose whether to default to Page Number or Percentage when setting progress.")
                <<< ThemedPushRow<ProgressType> {
                    $0.title = "Default Progress Type"
                    $0.options = [.page, .percentage]
                    $0.value = GeneralSettings.defaultProgressType
                    $0.onChange {
                        guard let newValue = $0.value else { return }
                        GeneralSettings.defaultProgressType = newValue
                    }
                }

            +++ Section(header: "Language", footer: """
                By default, Reading List prioritises search results based on their language and your location. To instead \
                restrict search results to be of a specific language only, select a language above.
                """)
                <<< SwitchRow {
                    $0.title = "Remember Last Selection"
                    $0.value = GeneralSettings.prepopulateLastLanguageSelection
                    $0.onChange {
                        guard let newValue = $0.value else { return }
                        GeneralSettings.prepopulateLastLanguageSelection = newValue
                        if !newValue {
                            LightweightDataStore.lastSelectedLanguage = nil
                        }
                    }
                }
                <<< PickerInlineRow<LanguageSelection> {
                    $0.title = "Restrict Search Results"
                    $0.options = [.none] + LanguageIso639_1.allCases.filter { $0.canFilterGoogleSearchResults }.map { .some($0) }
                    $0.value = {
                        if let languageRestriction = GeneralSettings.searchLanguageRestriction {
                            return .some(languageRestriction)
                        } else {
                            return LanguageSelection.none
                        }
                    }()
                    $0.onChange {
                        if let languageSelection = $0.value, case let .some(language) = languageSelection {
                            GeneralSettings.searchLanguageRestriction = language
                        } else {
                            GeneralSettings.searchLanguageRestriction = nil
                        }
                        UserEngagement.logEvent(.changeSearchOnlineLanguage)
                    }
                }

            +++ Section(header: "Analytics", footer: """
                Crash reports can be automatically sent to help me detect and fix issues. Analytics can \
                be used to help gather usage statistics for different features. This never includes any \
                details of your books.\
                \(BuildInfo.thisBuild.type != .testFlight ? "" : " If Beta testing, these cannot be disabled.")
                """)
                <<< SwitchRow {
                    $0.title = "Send Crash Reports"
                    $0.disabled = Condition(booleanLiteral: BuildInfo.thisBuild.type == .testFlight)
                    $0.onChange { [unowned self] in
                        self.crashReportsSwitchChanged($0)
                    }
                    $0.value = UserEngagement.sendCrashReports
                }
                <<< SwitchRow {
                    $0.title = "Send Analytics"
                    $0.disabled = Condition(booleanLiteral: BuildInfo.thisBuild.type == .testFlight)
                    $0.onChange { [unowned self] in
                        self.analyticsSwitchChanged($0)
                    }
                    $0.value = UserEngagement.sendAnalytics
                }

        monitorThemeSetting()
    }

    func crashReportsSwitchChanged(_ sender: _SwitchRow) {
        guard let switchValue = sender.value else { return }
        if switchValue {
            UserEngagement.sendCrashReports = true
            UserEngagement.initialiseUserAnalytics()
            UserEngagement.logEvent(.enableCrashReports)
        } else {
            // If this is being turned off, let's try to persuade them to turn it back on
            persuadeToKeepOn(title: "Turn Off Crash Reports?", message: """
                Anonymous crash reports alert me if this app crashes, to help me fix bugs. \
                This never includes any information about your books. Are you \
                sure you want to turn this off?
                """) { result in
                if result {
                    sender.value = true
                    sender.reload()
                } else {
                    UserEngagement.logEvent(.disableCrashReports)
                    UserEngagement.sendCrashReports = false
                }
            }
        }
    }

    func analyticsSwitchChanged(_ sender: _SwitchRow) {
        guard let switchValue = sender.value else { return }
        if switchValue {
            UserEngagement.sendAnalytics = true
            UserEngagement.initialiseUserAnalytics()
            UserEngagement.logEvent(.enableAnalytics)
        } else {
            // If this is being turned off, let's try to persuade them to turn it back on
            persuadeToKeepOn(title: "Turn Off Analytics?", message: """
                Anonymous usage statistics help prioritise development. This never includes \
                any information about your books. Are you sure you want to turn this off?
                """) { result in
                if result {
                    sender.value = true
                    sender.reload()
                } else {
                    UserEngagement.logEvent(.disableAnalytics)
                    UserEngagement.sendAnalytics = false
                }
            }
        }
    }

    func persuadeToKeepOn(title: String, message: String, completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Turn Off", style: .destructive) { _ in
            completion(false)
        })
        alert.addAction(UIAlertAction(title: "Leave On", style: .default) { _ in
            completion(true)
        })
        present(alert, animated: true)
    }
}

extension Notification.Name {
    static let ThemeSettingChanged = Notification.Name("theme-setting-changed")
}
