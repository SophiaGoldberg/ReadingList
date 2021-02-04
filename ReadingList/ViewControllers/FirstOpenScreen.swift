import Foundation
import UIKit
import WhatsNewKit
import ReadingList_Foundation

struct FirstOpenScreenProvider {
    func build(onDismiss: (() -> Void)? = nil) -> UIViewController {
        let readingList = "Reading List"
        let title = "Welcome to \(readingList)"
        let whatsNew = WhatsNew(title: title, items: [
            WhatsNew.Item(
                title: "Track Your Reading",
                subtitle: "Easily record the start and finish dates of every book you read",
                image: UIImage(largeSystemImageNamed: "calendar")
            ),
            WhatsNew.Item(
                title: "Easily Add Books",
                subtitle: "Add your books by scanning a barcode, or by searching online",
                image: UIImage(largeSystemImageNamed: "magnifyingglass")
            ),
            WhatsNew.Item(
                title: "Write Notes",
                subtitle: "Add star ratings and notes to your books",
                image: UIImage(largeSystemImageNamed: "star.fill")
            ),
            WhatsNew.Item(
                title: "Organise Your Books",
                subtitle: "Create your own lists to organise your library",
                image: UIImage(largeSystemImageNamed: "tray.full")
            ),
            WhatsNew.Item(
                title: "Privacy Focused",
                subtitle: "All data is kept fully private",
                image: UIImage(largeSystemImageNamed: "lock.fill")
            )
        ])

        var config = WhatsNewViewController.Configuration()
        config.itemsView.imageSize = .fixed(height: 40)
        if let startIndex = title.startIndex(ofFirstSubstring: readingList) {
            config.titleView.secondaryColor = .init(startIndex: startIndex, length: readingList.count, color: .systemBlue)
        } else {
            assertionFailure("Could not find title substring")
        }
        config.detailButton = WhatsNewViewController.DetailButton(
            title: "Learn more",
            action: .website(url: "https://readinglist.app/about")
        )
        config.completionButton = WhatsNewViewController.CompletionButton(
            title: "Continue",
            action: .custom { controller in
                controller.dismiss(animated: true, completion: onDismiss)
            }
        )

        return WhatsNewViewController(whatsNew: whatsNew, configuration: config)
    }
}
