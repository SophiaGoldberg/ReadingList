import XCTest

class ManualEntry: XCTestCase {

    private let defaultLaunchArguments = ["--reset", "--UITests", "--UITests_PopulateData"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testAddManualBook() {
        let app = ReadingListApp()
        app.launchArguments = defaultLaunchArguments
        app.launch()
        app.clickTab(.toRead)

        let initialNumberOfCells = Int(app.tables.cells.count)
        app.clickAddButton(addMethod: .enterManually)
        sleep(1)
        app.tables.textFields.element(boundBy: 0).tap()
        sleep(1)
        app.typeText("The Catcher in the Rye")

        app.tables.staticTexts["Add Author"].tap()
        app.tables.textFields["First Name(s)"].tap()
        app.typeText("J.D.")
        app.tables.textFields["Last Name"].tap()
        app.typeText("Salinger")
        app.navigationBars.element(boundBy: 0).buttons["Add Book"].tap()

        app.navigationBars.element(boundBy: 0).buttons["Next"].tap()
        app.navigationBars.element(boundBy: 0).buttons["Done"].tap()

        sleep(1)
        XCTAssertEqual(app.tables.cells.count, initialNumberOfCells + 1)
    }

    func testEditBook() {
        let app = ReadingListApp()
        app.launchArguments = defaultLaunchArguments
        app.launch()

        app.clickTab(.toRead)
        app.tables.cells.element(boundBy: 0).tap()
        app.scrollViews.otherElements.buttons["Edit"].tap()

        app.tables.textFields.element(boundBy: 0).tap()
        app.typeText("changed!")
        app.navigationBars.matching(identifier: "Edit Book").buttons["Done"].tap()
    }

    func testDeleteBook() {
        let app = ReadingListApp()
        app.launchArguments = defaultLaunchArguments
        app.launch()

        app.clickTab(.toRead)
        let bookCount = Int(app.tables.element(boundBy: 0).cells.count)

        app.tables.cells.element(boundBy: 0).tap()
        app.scrollViews.otherElements.buttons["Edit"].tap()

        app.tables.staticTexts["Delete"].tap()
        app.sheets.buttons["Delete"].tap()

        sleep(1)
        XCTAssertEqual(app.tables.cells.count, bookCount - 1)
    }
}
