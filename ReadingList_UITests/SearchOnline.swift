import Foundation
import XCTest

class SearchOnlineTests: XCTestCase {

    let mockServer = MockServer()
    private let defaultLaunchArguments = ["--reset", "--UITests", "--UITests_MockHttpCalls"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        try! mockServer.server.start()
    }

    override func tearDown() {
        super.tearDown()
        mockServer.server.stop()
    }

    private func performSearch(_ app: ReadingListApp) {
        app.clickAddButton(addMethod: .searchOnline)
        sleep(1)
        app.typeText("Orwell")
        app.buttons["Search"].tap()
        sleep(1)
    }

    func testSearchAddMany() {
        let app = ReadingListApp()
        app.launchArguments = defaultLaunchArguments
        app.launch()

        performSearch(app)
        let toolbar = app.toolbars["Toolbar"]
        // The Select Many button has spaces padding it, so don't do an exact sting comparison - just check it contains the Select Many string.
        let selectManyButton = toolbar.buttons.allElementsBoundByIndex.first { $0.label.contains("Select Many") }
        selectManyButton!.tap()

        app.tables.cells.element(boundBy: 0).tap()
        app.tables.cells.element(boundBy: 1).tap()
        toolbar.buttons["Add 2 Books"].tap()
        app.sheets["Add 2 Books"].buttons["Add All"].tap()
        sleep(1)
        XCTAssertEqual(app.tables.cells.count, 2)
    }

    func testSearchAddOne() {
        let app = ReadingListApp()
        app.launchArguments = defaultLaunchArguments
        app.launch()

        performSearch(app)
        app.tables.cells.element(boundBy: 4).tap()
        app.navigationBars.element(boundBy: 0).buttons["Done"].tap()
        sleep(2)
        XCTAssertEqual(app.tables.cells.count, 1)

        performSearch(app)
        app.tables.cells.element(boundBy: 4).tap()
        let duplicateAlert = app.alerts.element(boundBy: 0)
        XCTAssertEqual("Book Already Added", duplicateAlert.label)
        app.alerts["Book Already Added"].buttons["Go To Existing Book"].tap()
        sleep(1)
    }
}
