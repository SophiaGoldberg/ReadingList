import SwiftUI

struct Attributions: View {
    @EnvironmentObject var hostingSplitView: HostingSettingsSplitView

    let mitText = """
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

    var body: some View {
        SwiftUI.List {
            Section(header: HeaderText("Attributions", inset: hostingSplitView.isSplit)) {
                Group {
                    AttributionView(title: "Reading List App Icon", url: URL(string: "http://www.pixelresort.com/")!, text: ["PixelResort", "Designed by Michael Flarup"])
                    AttributionLicenceView("CHCSVParser", url: "https://github.com/davedelong/CHCSVParser", copyright: "2014 Dave DeLong", license: .mit)
                    AttributionLicenceView("Cosmos", url: "https://github.com/evgenyneu/Cosmos", copyright: "2015 Evgenii Neumerzhitckii", license: .mit)
                    AttributionLicenceView("Eureka", url: "https://github.com/xmartlabs/Eureka", copyright: "2015 XMARTLABS", license: .mit)
                    AttributionLicenceView("Icons8", url: "https://icons8.com", copyright: "Icons8", license: .ccByNd3)
                    AttributionLicenceView("PersistedPropertyWrapper", url: "https://github.com/AndrewBennet/PersistedPropertyWrapper", copyright: "2020 Andrew Bennet", license: .mit)
                    AttributionLicenceView("Promises", url: "https://github.com/google/promises", copyright: "2018 Google Inc", license: .apache2)
                    AttributionLicenceView("Regex", url: "https://github.com/sharplet/Regex", copyright: "2015 Adam Sharp", license: .mit)
                    AttributionLicenceView("SwiftyStoreKit", url: "https://github.com/bizz84/SwiftyStoreKit", copyright: "2015-2017 Andrea Bizzotto", license: .mit)
                    AttributionLicenceView("SVProgressHUD", url: "https://github.com/SVProgressHUD/SVProgressHUD", copyright: "2011-2018 Sam Vermette, Tobias Tiemerding and contributors", license: .mit)
                }
                Group {
                    AttributionLicenceView("WhatsNewKit", url: "https://github.com/SvenTiigi/WhatsNewKit", copyright: "2020 Sven Tiigi", license: .mit)
                    AttributionLicenceView("ZIPFoundation", url: "https://github.com/weichsel/ZIPFoundation", copyright: "2017-2020 Thomas Zoechling", license: .mit)
                }
            }
            Section(header: HeaderText("MIT Licence", inset: hostingSplitView.isSplit)) {
                Text(mitText)
                    .padding([.top, .bottom], 8)
                    .font(.caption)
            }
        }
        .possiblyInsetGroupedListStyle(inset: hostingSplitView.isSplit)
        .navigationBarTitle("Attributions")
    }
}

struct AttributionLicenceView: View {
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

    var body: some View {
        AttributionView(title: title, url: url, text: [
            "Copyright © \(copyright)",
            "Provided under the \(license.description) License"
        ])
    }
}

struct AttributionView: View {
    let title: String
    let url: URL
    let text: [String]

    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.body)
            ForEach(text, id: \.self) {
                Text($0).font(.caption)
            }
        }.presentingSafari(url)
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

struct Attributions_Previews: PreviewProvider {
    static var previews: some View {
        Attributions()
    }
}
