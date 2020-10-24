import Foundation
import UIKit

final class Attributions: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableView.automaticDimension
        monitorThemeSetting()
    }

    private let attributions = [
        Attribution("CHCSVParser", url: "https://github.com/davedelong/CHCSVParser", copyright: "2014 Dave DeLong", license: .mit),
        Attribution("Cosmos", url: "https://github.com/evgenyneu/Cosmos", copyright: "2015 Evgenii Neumerzhitckii", license: .mit),
        Attribution("Eureka", url: "https://github.com/xmartlabs/Eureka", copyright: "2015 XMARTLABS", license: .mit),
        Attribution("Icons8", url: "https://icons8.com", copyright: "Icons8", license: .ccByNd3),
        Attribution("PersistedPropertyWrapper", url: "https://github.com/AndrewBennet/PersistedPropertyWrapper", copyright: "2020 Andrew Bennet", license: .mit),
        Attribution("Promises", url: "https://github.com/google/promises", copyright: "2018 Google Inc", license: .apache2),
        Attribution("Regex", url: "https://github.com/sharplet/Regex", copyright: "2015 Adam Sharp", license: .mit),
        Attribution("SwiftyStoreKit", url: "https://github.com/bizz84/SwiftyStoreKit", copyright: "2015-2017 Andrea Bizzotto", license: .mit),
        Attribution("SVProgressHUD", url: "https://github.com/SVProgressHUD/SVProgressHUD", copyright: "2011-2018 Sam Vermette, Tobias Tiemerding and contributors", license: .mit),
        Attribution("WhatsNewKit", url: "https://github.com/SvenTiigi/WhatsNewKit", copyright: "2020 Sven Tiigi", license: .mit)
    ]

    override func numberOfSections(in tableView: UITableView) -> Int { return 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return attributions.count
        } else {
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Attributions"
        } else {
            return "MIT License"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Basic", for: indexPath)
            guard let textLabel = cell.textLabel else { preconditionFailure() }
            if #available(iOS 13.0, *) { } else {
                cell.defaultInitialise(withTheme: GeneralSettings.theme)
            }
            textLabel.text = """
            Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated \
            documentation files (the "Software"), to deal in the Software without restriction, including without limitation \
            the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, \
            and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

            The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO \
            THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
            AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, \
            TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
            """
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "Attribution", for: indexPath)
        guard let textLabel = cell.textLabel, let detailTextLabel = cell.detailTextLabel else { preconditionFailure() }
        if #available(iOS 13.0, *) { } else {
            cell.defaultInitialise(withTheme: GeneralSettings.theme)
        }

        let attribution = attributions[indexPath.row]
        textLabel.text = attribution.title
        detailTextLabel.text = "Copyright © \(attribution.copyright)\nProvided under the \(attribution.license.description) License"

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0 else { return }
        presentThemedSafariViewController(attributions[indexPath.row].url)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

enum License: CustomStringConvertible {
    case mit
    case ccByNd3
    case apache2

    var description: String {
        switch self {
        case .mit: return "MIT"
        case .ccByNd3: return "CC-BY-ND 3.0"
        case .apache2: return "Apache 2.0"
        }
    }
}

struct Attribution {
    let url: URL
    let title: String
    let copyright: String
    let license: License

    init(_ title: String, url: String, copyright: String, license: License) {
        self.title = title
        self.url = URL(string: url)!
        self.copyright = copyright
        self.license = license
    }
}
