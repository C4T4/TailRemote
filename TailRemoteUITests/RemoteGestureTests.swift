import XCTest

final class RemoteGestureTests: XCTestCase {
    private var app: XCUIApplication!
    private var canvas: XCUIElement { app.otherElements["remote-gesture-canvas"] }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--test-remote-gestures"]
        app.launch()
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
    }

    func testSwipeMovesWithoutClickingOrPressingMouseButton() {
        swipe(distance: 100, velocity: 200)

        XCTAssertGreaterThan(value("moves"), 0)
        XCTAssertEqual(value("clicks"), 0)
        XCTAssertEqual(value("downs"), 0)
        XCTAssertEqual(value("ups"), 0)
        XCTAssertLessThan(value("maxDelta"), 25, "Movement must not buffer behind a long press")
    }

    func testSlowShortSwipeDoesNotBecomeADragOrClick() {
        // Previously the hold accepted up to 36pt of travel for 0.3 seconds,
        // so this ordinary 24pt swipe could send mouse-down instead of moving.
        swipe(distance: 24, velocity: 60)

        XCTAssertGreaterThan(value("moves"), 0)
        XCTAssertEqual(value("clicks"), 0)
        XCTAssertEqual(value("downs"), 0)
        XCTAssertEqual(value("ups"), 0)
    }

    func testSingleAndDoubleTapStillClick() {
        canvas.tap()
        expectValue("clicks", equals: 1)
        canvas.doubleTap()
        expectValue("clicks", equals: 3)
        XCTAssertEqual(value("moves"), 0)
        XCTAssertEqual(value("downs"), 0)
    }

    func testStationaryHoldThenMoveDragsAndReleasesOnce() {
        swipe(distance: 80, velocity: 150, hold: 0.6)

        XCTAssertGreaterThan(value("moves"), 0)
        XCTAssertEqual(value("downs"), 1)
        XCTAssertEqual(value("ups"), 1)
        XCTAssertEqual(value("clicks"), 0, "Finishing a drag must not add a tap")

        canvas.tap()
        expectValue("clicks", equals: 1)
        XCTAssertEqual(value("downs"), 1)
        XCTAssertEqual(value("ups"), 1)
    }

    func testTwoFingerTapStillRightClicks() {
        canvas.twoFingerTap()
        expectValue("rightClicks", equals: 1)
        XCTAssertEqual(value("clicks"), 0)
        XCTAssertEqual(value("downs"), 0)
    }

    private func swipe(distance: CGFloat, velocity: Double, hold: TimeInterval = 0) {
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
        let end = start.withOffset(CGVector(dx: distance, dy: 0))
        start.press(forDuration: hold, thenDragTo: end, withVelocity: XCUIGestureVelocity(rawValue: velocity), thenHoldForDuration: 0)
    }

    private func value(_ key: String) -> Double {
        let values = (canvas.value as? String ?? "").split(separator: ",")
        let match = values.first { $0.hasPrefix("\(key)=") }
        return match.flatMap { Double($0.split(separator: "=")[1]) } ?? -1
    }

    private func expectValue(_ key: String, equals expected: Double) {
        let predicate = NSPredicate { [self] _, _ in value(key) == expected }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
    }
}
