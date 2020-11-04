import Foundation
import Eureka

final class SortOrder: FormViewController {

    override func viewDidLoad() {
        if #available(iOS 13.0, *) {
            initialiseInsetGroupedTable()
        }

        super.viewDidLoad()

        form +++ Section(header: "Sort Options", footer: """
            Configure whether newly added books get added to the top or the bottom of the \
            reading list when Custom ordering is used.
            """)
            <<< SwitchRow {
                $0.title = "Add Books to Top"
                $0.value = GeneralSettings.addBooksToTopOfCustom
                $0.onChange {
                    GeneralSettings.addBooksToTopOfCustom = $0.value ?? false
                }
            }
        monitorThemeSetting()
    }
}
