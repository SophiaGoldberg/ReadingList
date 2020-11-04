import Foundation
import XCTest

class Lists: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testFirstListPresentsAlertAndSecondListPresentsModal() {
        let app = ReadingListApp()
        app.launchArguments = ["--reset", "--UITests_PopulateData", "--UITests_DeleteLists"]
        app.launch()

        app.tables.cells.element(boundBy: 0).tap()
        app.scrollViews.otherElements.buttons["Manage Lists"].tap()

        XCTAssertEqual(app.alerts.count, 1, "Alert should appear when adding first list")
        let addNewListAlert = app.alerts.firstMatch
        let enterListNameTextField = addNewListAlert.collectionViews.textFields.firstMatch
        enterListNameTextField.typeText("A List")
        addNewListAlert.buttons["OK"].tap()

        app.clickTab(.organise)
        XCTAssertEqual(app.tables.cells.count, 1, "Should be one list in organise tab")

        app.clickTab(.toRead)
        app.scrollViews.otherElements.buttons["Manage Lists"].tap()

        let modalTable = app.tables.element(boundBy: 0)
        XCTAssertEqual(modalTable.cells.count, 2, "Should be 2 table rows in modal list selector")

        modalTable.cells.element(boundBy: 0).tap()
        XCTAssertEqual(app.alerts.count, 1, "Alert should appear when adding new list")
        let addList2Alert = app.alerts.firstMatch
        let enterList2NameTextField = addList2Alert.collectionViews.textFields.firstMatch
        enterList2NameTextField.typeText("B List")
        addList2Alert.buttons["OK"].tap()
    }

    func testListOrders() {
        let app = ReadingListApp()
        app.launchArguments = ["--reset", "--UITests_PopulateData"]
        app.launch()
        app.clickTab(.organise)
        app.tables.cells.element(boundBy: 0).tap()

        let orderButton = app.navigationBars.firstMatch.buttons.element(boundBy: 1)
        orderButton.tap()
        let chooseOrderAlert = app.sheets["Choose Order"]
        for button in chooseOrderAlert.buttons.allElementsBoundByIndex {
            button.tap()
            orderButton.tap()
        }
    }
}
