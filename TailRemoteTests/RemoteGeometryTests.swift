import CoreGraphics
import XCTest
@testable import TailRemote

final class RemoteGeometryTests: XCTestCase {
    func testAspectFitCentersWideDesktop() {
        let rect = RemoteGeometry.aspectFitRect(
            imageSize: CGSize(width: 1920, height: 1080),
            in: CGRect(x: 0, y: 0, width: 390, height: 844)
        )

        XCTAssertEqual(rect.width, 390, accuracy: 0.001)
        XCTAssertEqual(rect.height, 219.375, accuracy: 0.001)
        XCTAssertEqual(rect.midY, 422, accuracy: 0.001)
    }

    func testClampKeepsPointerInsideFramebuffer() {
        let point = RemoteGeometry.clamp(
            CGPoint(x: -20, y: 1400),
            to: CGSize(width: 1920, height: 1080)
        )

        XCTAssertEqual(point.x, 0)
        XCTAssertEqual(point.y, 1079)
    }

    func testPointerDeltaScalesToRemoteDesktop() {
        let delta = RemoteGeometry.framebufferDelta(
            fromViewDelta: CGPoint(x: 10, y: -5),
            framebufferSize: CGSize(width: 1920, height: 1080),
            viewSize: CGSize(width: 390, height: 844),
            sensitivity: 1
        )

        XCTAssertEqual(delta.x, 49.2307, accuracy: 0.001)
        XCTAssertEqual(delta.y, -24.6153, accuracy: 0.001)
    }

    func testZoomScaleIsLimitedToOneThroughFour() {
        XCTAssertEqual(RemoteGeometry.clampedZoomScale(0.5), 1)
        XCTAssertEqual(RemoteGeometry.clampedZoomScale(2.5), 2.5)
        XCTAssertEqual(RemoteGeometry.clampedZoomScale(8), 4)
    }

    func testPanOffsetStaysInsideZoomedDesktop() {
        let offset = RemoteGeometry.clampedPanOffset(
            CGPoint(x: 500, y: -500),
            baseRect: CGRect(x: 0, y: 0, width: 390, height: 220),
            viewportRect: CGRect(x: 0, y: 0, width: 390, height: 844),
            zoomScale: 2
        )

        XCTAssertEqual(offset.x, 195)
        XCTAssertEqual(offset.y, 0)
    }

    func testPanOffsetSupportsBothAxesWhenContentExceedsViewport() {
        let offset = RemoteGeometry.clampedPanOffset(
            CGPoint(x: 900, y: -900),
            baseRect: CGRect(x: 0, y: 312, width: 390, height: 220),
            viewportRect: CGRect(x: 56, y: 88, width: 278, height: 668),
            zoomScale: 4
        )

        XCTAssertEqual(offset.x, 641)
        XCTAssertEqual(offset.y, -106)
    }

    func testViewportFollowsCursorAtZoomedEdge() {
        let offset = RemoteGeometry.panOffsetFollowingCursor(
            normalizedCursorPoint: CGPoint(x: 1, y: 1),
            currentOffset: .zero,
            baseRect: CGRect(x: 0, y: 312, width: 390, height: 220),
            viewportRect: CGRect(x: 56, y: 88, width: 278, height: 668),
            zoomScale: 4
        )

        XCTAssertEqual(offset.x, -641)
        XCTAssertEqual(offset.y, -106)
    }

    func testPinchKeepsFocalPointStationary() {
        let offset = RemoteGeometry.panOffsetKeepingFocalPointStable(
            currentOffset: .zero,
            focalPoint: CGPoint(x: 100, y: 300),
            baseCenter: CGPoint(x: 195, y: 422),
            oldScale: 1,
            newScale: 2
        )

        XCTAssertEqual(offset.x, 95)
        XCTAssertEqual(offset.y, 122)
    }

    func testZoomedRectUsesScaleAndPanOffset() {
        let rect = RemoteGeometry.zoomedRect(
            baseRect: CGRect(x: 0, y: 300, width: 390, height: 220),
            zoomScale: 2,
            panOffset: CGPoint(x: 40, y: -20)
        )

        XCTAssertEqual(rect, CGRect(x: -155, y: 170, width: 780, height: 440))
    }
}
