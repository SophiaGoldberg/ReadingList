import Foundation
import SwiftUI

struct PrivacyPolicy: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Text("""
                # Privacy Policy

                ## Summary
                Reading List is a free, open-source app, developed by Andrew Bennet. Reading List does not actively collect any data about the books you add. It does, however, use some third-party services to report app crashes, and to track some usage analytics. These can both be disabled within the app. It also uses a third-party service to provide a source of book metadata, and contains links to some third-party websites; when used, these services may additionally collect some data. This privacy policy provides information about how this data is used. If you have any questions, please email feedback@readinglist.app.

                ## Data Collected By Reading List
                ### Crash Reports
                In order to improve the stability of the app, a service is used to detect and report any crashes which may occur. This information is collected by a third party service Crashlytics, provided by Fabric; for full details you should consult the privacy policy of Fabric Crashlytics. Any reported crash will include some device information - such as the model, the app version, the iOS version and the amount of free RAM and storage space - as well as details of the code which was being executed at the point that the app crashed. On very rare occasions, error details may include more specific information, such as a piece of metadata from a book, if that information is related to the crash. This information is not used for any purposes other than diagnosing app bugs to enable them to be fixed and thus provide a more stable service. Additionally, this service reports the aggregate total number of users of the app, in order to calculate the percentage occurance of each crash. You can opt out of this data collection at Settings &rarr; General &rarr; Enable Crash Reports.

                ### Analytics
                In order to assess the comparative usage of different app features, a service is used to report some key app actions. This information is collected by a third party service called Google Firebase Analytics; for full details you should consult the privacy policy of Google Firebase. This information is tracked for the puposes of determining which features are more frequently used, and so should be more actively developed. This service reports some device information, including the device model, iOS version and approximate location (e.g. country). This service reports user navigation through different screens within the app, as well as some specific in-app events, including:

                - Performing an online search
                - Scanning a barcode
                - Adding a book manually
                - Updating book metadata manually
                - Changing the theme
                - Changing the book sort order
                - Exporting data to CSV
                - Importing data from CSV

                Please note that none of these events include any information about any of your books. For example, the _Online Search_ event reports that a book was added via an online search, but not any details of that new book, nor the search terms used. You can opt out of this data collection at Settings &rarr; General &rarr; Enable Analytics.

                ## Data Collected By Other Services

                ### Book Search Data
                When adding books via a method which looks up book metadata online, that data is obtained from Google Books. If you scan a barcode, the ISBN from the barcode is provided to Google Books in order to obtain book metadata. If you search online, your search terms are provided to Google Books in order to obtain book metadata. This service may also collect some other information from your device, such as the IP address and model number. For details, consult the Google Books Privacy Policy.

                ### Links to Other Sites
                This app contains some links to third-party websites. If you click on a link to an third-party website, you will be directed to that site. These external sites are not operated by me, and thus you should review the Privacy Policy of these websites. The sites linked to by this app include: links to the licence agreements of third-party code libraries, links to books on Google Books, links to books on Amazon, a link to the source code of this app on GitHub, and links to Apple's TestFlight beta testing platform.

                ## Changes to This Privacy Policy
                I may update our Privacy Policy from time to time. You should review policy for any changes; I will notify you of any changes by updating the new Privacy Policy on this page. These changes are effective immediately.

                ## Contact
                If you have any questions or suggestions about this Privacy Policy, do not hesitate to contact me at feedback@readinglist.app.
                """
            ).font(.system(size: 13, design: .monospaced))
            .padding()
        }
    }
}
