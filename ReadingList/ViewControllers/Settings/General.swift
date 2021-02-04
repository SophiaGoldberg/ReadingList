import SwiftUI
import ReadingList_Foundation

class GeneralSettingsObservable: ObservableObject {
    @Published var addBooksToTop: Bool = GeneralSettings.addBooksToTopOfCustom {
        didSet {
            GeneralSettings.addBooksToTopOfCustom = addBooksToTop
        }
    }

    @Published var progressType = GeneralSettings.defaultProgressType {
        didSet { GeneralSettings.defaultProgressType = progressType }
    }

    @Published var prepopulateLastLanguageSelection = GeneralSettings.prepopulateLastLanguageSelection {
        didSet {
            GeneralSettings.prepopulateLastLanguageSelection = prepopulateLastLanguageSelection
            if !prepopulateLastLanguageSelection { LightweightDataStore.lastSelectedLanguage = nil }
        }
    }
    @Published var restrictSearchResultsTo: LanguageSelection = {
        if let languageRestriction = GeneralSettings.searchLanguageRestriction {
            return .some(languageRestriction)
        } else {
            return LanguageSelection.none
        }
    }() {
        didSet {
            if case .some(let selection) = restrictSearchResultsTo {
                GeneralSettings.searchLanguageRestriction = selection
            } else {
                GeneralSettings.searchLanguageRestriction = .none
            }
        }
    }
}

struct General: View {

    @EnvironmentObject var hostingSplitView: HostingSettingsSplitView
    @ObservedObject var settings = GeneralSettingsObservable()

    private var inset: Bool {
        hostingSplitView.isSplit
    }

    private let languageOptions = [LanguageSelection.none] + LanguageIso639_1.allCases.filter { $0.canFilterGoogleSearchResults }.map { .some($0) }

    var body: some View {
        SwiftUI.List {
            Section(
                header: HeaderText("Sort Options", inset: hostingSplitView.isSplit),
                footer: FooterText("""
                    Configure whether newly added books get added to the top or the bottom of the \
                    reading list when Custom ordering is used.
                    """, inset: hostingSplitView.isSplit
                )
            ) {
                Toggle(isOn: $settings.addBooksToTop) {
                    Text("Add Books to Top")
                }
            }
            Section(
                header: HeaderText("Progress", inset: inset),
                footer: FooterText("Choose whether to default to Page Number or Percentage when setting progress.", inset: inset)
            ) {
                NavigationLink(
                    destination: SelectionForm<ProgressType>(
                        options: [.page, .percentage],
                        selectedOption: $settings.progressType
                    ).navigationBarTitle("Default Progress Type")
                ) {
                    HStack {
                        Text("Progress Type")
                        Spacer()
                        Text(settings.progressType.description)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(
                header: HeaderText("Language", inset: inset),
                footer: FooterText("""
                    By default, Reading List prioritises search results based on their language and your location. To instead \
                    restrict search results to be of a specific language only, select a language above.
                    """, inset: inset)
            ) {
                Toggle(isOn: $settings.prepopulateLastLanguageSelection) {
                    Text("Remember Last Selection")
                }
                NavigationLink(
                    destination: SelectionForm<LanguageSelection>(
                        options: languageOptions,
                        selectedOption: $settings.restrictSearchResultsTo
                    ).navigationBarTitle("Language Restriction")
                ) {
                    HStack {
                        Text("Restrict Search Results")
                        Spacer()
                        Text(settings.restrictSearchResultsTo.description).foregroundColor(.secondary)
                    }
                }
            }
        }
        .possiblyInsetGroupedListStyle(inset: hostingSplitView.isSplit)
        .navigationBarTitle("General", displayMode: .inline)
    }
}

extension ProgressType: Identifiable {
    var id: Int { rawValue }
}

extension LanguageSelection: Identifiable {
    var id: String {
        switch self {
        case .none: return ""
        // Not in practise used by this form; return some arbitrary unique value
        case .blank: return "!"
        case .some(let language): return language.rawValue
        }
    }
}

struct General_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            General().environmentObject(HostingSettingsSplitView())
        }
    }
}
