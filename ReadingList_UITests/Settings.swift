import XCTest

class Settings: XCTestCase {

    private let defaultLaunchArguments = ["--reset", "--UITests", "--UITests_PopulateData"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testExportBook() {
        let app = ReadingListApp()
        app.launchArguments = defaultLaunchArguments
        app.launch()

        app.clickTab(.settings)
        app.tables.staticTexts["Import / Export"].tap()
        app.tables.staticTexts["Export"].tap()
        sleep(3)

        // Can't find a way to tap the exit X button in the top right of the activity sheet on iOS 13 - just end the test here.
    }

    func testSortOrders() {
        let app = ReadingListApp()
        app.launchArguments = defaultLaunchArguments
        app.launch()

        func testAllSorts() {
            let sortButton = app.tables.otherElements.firstMatch.children(matching: .button).element
            var buttonIndex = 0
            while true {
                sortButton.tap()
                let chooseOrderSheet = app.sheets["Choose Order"]
                let sortSheetButton = chooseOrderSheet.buttons.element(boundBy: buttonIndex)
                if !sortSheetButton.exists {
                    chooseOrderSheet.buttons.allElementsBoundByIndex.last?.tap()
                    break
                }
                sortSheetButton.tap()
                buttonIndex += 1
            }
        }

        app.clickTab(.toRead)
        // Scroll bar interfers with sort button tap; sleep to stop this
        sleep(2)
        testAllSorts()

        app.clickTab(.finished)
        // Scroll bar interfers with sort button tap; sleep to stop this
        sleep(2)
        testAllSorts()
    }
}
