import XCTest

class Screenshots: XCTestCase {

    let mockServer = MockServer()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        try! mockServer.server.start()

        let app = ReadingListApp()
        setupSnapshot(app)
        app.launchArguments = ["--reset", "--UITests", "--UITests_PopulateData", "--UITests_Screenshots", "--UITests_MockHttpCalls", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXL"]
        app.launch()
        sleep(5)
    }

    override func tearDown() {
        super.tearDown()
        mockServer.server.stop()
    }

    func testSnapshot() {

        // Screenshot is designed for iOS 14 only
        guard #available(iOS 14.0, *) else { return }

        let app = ReadingListApp()
        app.clickTab(.toRead)

        let isIpad = app.navigationBars.count == 2
        if isIpad {
            app.tables.cells.element(boundBy: 2).tap()
        }

        snapshot("0_ToReadList")
        app.clickTab(.finished)
        app.swipeUp()
        app.tables.staticTexts["The Color Purple"].tap()
        snapshot("1_BookDetails")

        if !isIpad {
            // go back
            app.navigationBars["The Color Purple"].buttons["Finished"].tap()
        }
        if isIpad {
            app.tables.staticTexts["The Great Gatsby"].tap()
            app.swipeDown()
        }
        app.navigationBars["Finished"].buttons["Add"].tap()
        app.collectionViews.buttons["Scan Barcode"].tap()
        snapshot("2_ScanBarcode")

        app.navigationBars["Scan Barcode"].buttons["Cancel"].tap()

        app.tabBars.buttons["Finished"].tap()
        app.tables.element(boundBy: 0).swipeDown()
        app.tables.element(boundBy: 0).swipeDown()

        let yourLibrarySearchField = app.searchFields["Your Library"]
        yourLibrarySearchField.tap()
        yourLibrarySearchField.typeText("Orwell")
        let swipeExplanationContinueButton = app.buttons["Continue"]
        if swipeExplanationContinueButton.exists {
            swipeExplanationContinueButton.tap()
        }
        app.buttons["Done"].tap()

        if isIpad {
            app.tables.staticTexts["1984"].tap()
        }

        snapshot("3_SearchFinished")
        app.buttons["Cancel"].tap()

        if isIpad {
            app.tables.cells.element(boundBy: 3).tap()
        }
        app.navigationBars["Finished"].buttons["Edit"].tap()
        app.tables.cells.element(boundBy: 5).tap()
        app.tables.cells.element(boundBy: 8).tap()
        app.tables.cells.element(boundBy: 6).tap()
        app.tables.cells.element(boundBy: 7).tap()
        snapshot("4_BulkEdit")

        app.tabBars.buttons.element(boundBy: 2).tap()
        app.tables.cells.element(boundBy: 0).tap()
        if isIpad {
            app.tables.cells.element(boundBy: 6).tap()
        } else {
            app.swipeUp()
        }
        snapshot("5_Organise")
    }
}
