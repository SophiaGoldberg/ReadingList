import UIKit
import os.log

class SplitViewController: UISplitViewController, UISplitViewControllerDelegate {

    /**
        Whether the view has yet appeared. Set to true when viewDidAppear is called.
     */
    var hasAppeared = false
    var hostingSplitView: HostingSplitView?

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredDisplayMode = .allVisible
        delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        hasAppeared = true
        hostingSplitView?.isSplit = !isCollapsed
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Workarond for a very weird bug in the UISplitViewController in iOS 13 (FB7293182).
        // When a UITabViewController contains as its view controllers several UISplitViewControllers (such that
        // some are not visible in the initial view of the app), if the app is sent the background before the other
        // tabs are selected, then splitViewController(_:collapseSecondary:onto:) is not called, and thus the default
        // behaviour of showing the detail view when not split is used. For the Settings tab, this just means the
        // app opens up on the About menu, which is weird but not broken. For the other tabs, however, the app opens
        // up on un-initialised views. The BookDetails view controller, for example, will not have had a Book object
        // set, and so will just show a blank window. The user would have to tap the Back navigation button to get
        // to the table.
        // To work around this, we detect the case when this split view controller becoming visible for the first time,
        // with the detail view controller presented, but not in split mode (in split mode we expect both the master
        // and the detail view controllers to be visible initially). When this happens, we pop the master navigation
        // controller to return the master root controller to visibility.
        if hasAppeared { return }
        if !isSplit && detailIsPresented {
            os_log("UISplitViewController becoming visible, but with the detail view controller presented when not in split mode. Attempting to fix the problem by popping the master navigation view controller.", type: .default)
            self.masterNavigationController.popViewController(animated: false)
        }
    }

    @available(iOS 14.0, *)
    func splitViewControllerDidExpand(_ svc: UISplitViewController) {
        hostingSplitView?.isSplit = !isCollapsed
    }

    @available(iOS 14.0, *)
    func splitViewControllerDidCollapse(_ svc: UISplitViewController) {
        hostingSplitView?.isSplit = !isCollapsed
    }

    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        if #available(iOS 14.0, *) { } else {
            hostingSplitView?.isSplit = false
        }
        return true
    }

    func splitViewController(_ svc: UISplitViewController, willChangeTo displayMode: UISplitViewController.DisplayMode) {
        if #available(iOS 14.0, *) { } else {
            hostingSplitView?.isSplit = !isCollapsed
        }
    }
}

protocol HostingSplitView {
    var isSplit: Bool { get set }
}
