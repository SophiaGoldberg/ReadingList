import UIKit
import CoreSpotlight
import Eureka

final class TabBarController: UITabBarController {

    convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        initialise()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialise()
    }

    enum TabOption: Int {
        case toRead = 0
        case finished = 1
        case organise = 2
        case settings = 3
    }

    func initialise() {
        // The first two tabs of the tab bar controller are to the same storyboard. We cannot have different tab bar icons
        // if they are set up in storyboards, so we do them in code here, instead.
        let toRead = UIStoryboard.BookTable.instantiateRoot() as! UISplitViewController
        (toRead.masterNavigationRoot as! BookTable).readStates = [.reading, .toRead]

        let finished = UIStoryboard.BookTable.instantiateRoot() as! UISplitViewController
        (finished.masterNavigationRoot as! BookTable).readStates = [.finished]

        viewControllers = [toRead, finished, UIStoryboard.Organize.instantiateRoot(), UIStoryboard.Settings.instantiateRoot()]

        // Tabs 3 and 4 are already configured by the Organise and Settings storyboards
        tabBar.items![0].configure(tag: TabOption.toRead.rawValue, title: "To Read", image: #imageLiteral(resourceName: "courses"), selectedImage: #imageLiteral(resourceName: "courses-filled"))
        tabBar.items![1].configure(tag: TabOption.finished.rawValue, title: "Finished", image: #imageLiteral(resourceName: "to-do"), selectedImage: #imageLiteral(resourceName: "to-do-filled"))

        monitorThemeSetting()
    }

    var selectedTab: TabOption {
        get { return TabOption(rawValue: selectedIndex)! }
        set { selectedIndex = newValue.rawValue }
    }

    var selectedSplitViewController: UISplitViewController? {
        return selectedViewController as? UISplitViewController
    }

    var selectedBookTable: BookTable? {
        return selectedSplitViewController?.masterNavigationController.viewControllers.first as? BookTable
    }

    func simulateBookSelection(_ book: Book, allowTableObscuring: Bool) {
        selectedTab = book.readState == .finished ? .finished : .toRead
        // Crashes observed on iOS 13: simulateBookSelection crashed as implicitly unwrapped optionals were nil,
        // which could only be the case if viewDidLoad had not been called. Check whether the view is loaded, and
        // if not, schedule the work on the main thread, so that the view can be loaded first. Check again that
        // the view is loaded, to be safe.
        if selectedBookTable?.viewIfLoaded == nil {
            DispatchQueue.main.async { [unowned self] in
                if self.selectedBookTable?.viewIfLoaded != nil {
                    self.selectedBookTable!.simulateBookSelection(book.objectID, allowTableObscuring: allowTableObscuring)
                }
            }
        } else {
            selectedBookTable!.simulateBookSelection(book.objectID, allowTableObscuring: allowTableObscuring)
        }
    }

    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        // Scroll to top of table if the selected tab is already selected
        guard let selectedSplitViewController = selectedSplitViewController, item.tag == selectedIndex else { return }

        if selectedSplitViewController.masterNavigationController.viewControllers.count > 1 {
           selectedSplitViewController.masterNavigationController.popToRootViewController(animated: true)
        } else if let topVc = selectedSplitViewController.masterNavigationController.viewControllers.first,
            let topTable = (topVc as? UITableViewController)?.tableView ?? (topVc as? FormViewController)?.tableView,
            topTable.numberOfSections > 0, topTable.contentOffset.y > 0 {
                topTable.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        }
    }
}
