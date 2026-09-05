import XCTest

final class SavedCredentialsTests: XCTestCase {
    func testMacPickerRestoresMatchingAccountAndPassword() {
        let app = XCUIApplication()
        app.launchArguments = ["--test-credentials", "--reset-credential-test"]
        app.launch()
        let password = app.secureTextFields["remote-password"]
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        password.tap()
        password.typeText("synthetic-ui-password\n")
        let end = app.buttons["End"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        end.tap()
        let picker = app.buttons["mac-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        app.buttons["saved-mac-other.test.invalid"].tap()
        XCTAssertEqual(app.textFields["remote-username"].value as? String, "other-user")
        XCTAssertFalse(app.buttons["connect-to-mac"].isEnabled, "A different Mac must not receive the saved password")
        picker.tap()
        app.buttons["saved-mac-ui.test.invalid"].tap()
        XCTAssertEqual(app.textFields["remote-username"].value as? String, "test-user")
        XCTAssertTrue(app.buttons["connect-to-mac"].isEnabled)
        picker.tap()
        app.buttons["saved-mac-other.test.invalid"].tap()
        app.terminate()
        app.launchArguments = ["--test-credentials"]
        app.launch()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["remote-username"].value as? String, "other-user")
        XCTAssertFalse(app.buttons["connect-to-mac"].isEnabled)
        app.terminate()
    }

    func testSignInOnceThenReconnectAfterRelaunchAndForget() {
        let app = XCUIApplication()
        app.launchArguments = ["--test-credentials", "--reset-credential-test"]
        app.launch()
        let connect = app.buttons["connect-to-mac"]
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        XCTAssertFalse(connect.isEnabled)

        let password = app.secureTextFields["remote-password"]
        password.tap()
        password.typeText("synthetic-ui-password\n")
        let end = app.buttons["End"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        end.tap()
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        XCTAssertTrue(connect.isEnabled, "Returning from a connection should restore the saved password")

        app.terminate()
        app.launchArguments = ["--test-credentials"]
        app.launch()
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        XCTAssertTrue(connect.isEnabled, "The password must survive an app restart")
        if !connect.isHittable { app.swipeUp() }
        connect.tap()
        XCTAssertTrue(end.waitForExistence(timeout: 5), "Reconnect without entering any password")
        end.tap()
        XCTAssertTrue(connect.waitForExistence(timeout: 5))

        let remember = app.switches["remember-password"]
        if !remember.isHittable { app.swipeUp() }
        remember.tap()
        XCTAssertEqual(remember.value as? String, "0")
        app.terminate()
        app.launch()
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        XCTAssertFalse(connect.isEnabled, "Turning Remember off must remove the saved password")
        let rememberAfterRelaunch = app.switches["remember-password"]
        if !rememberAfterRelaunch.isHittable { app.swipeUp() }
        rememberAfterRelaunch.tap()
        XCTAssertFalse(connect.isEnabled, "Re-enabling Remember must not bring back a forgotten password")
        app.terminate()
    }
}
