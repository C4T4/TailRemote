#if DEBUG
import RoyalVNCKit
import SwiftUI

// Exercise the real UIKit gesture arbitration without connecting to a Mac or
// sending test clicks to somebody's desktop. Never included in release builds.
struct RemoteGestureTestView: UIViewRepresentable {
    func makeCoordinator() -> InputRecorder { InputRecorder() }

    func makeUIView(context: Context) -> RemoteCanvasUIView {
        let canvas = RemoteCanvasUIView()
        canvas.session = context.coordinator
        canvas.isAccessibilityElement = true
        canvas.accessibilityIdentifier = "remote-gesture-canvas"
        canvas.accessibilityLabel = "Remote gesture test canvas"
        context.coordinator.canvas = canvas
        canvas.update(image: nil, framebufferSize: InputRecorder.framebufferSize, cursorPoint: context.coordinator.cursorPoint)
        context.coordinator.publish()
        return canvas
    }

    func updateUIView(_ uiView: RemoteCanvasUIView, context: Context) {}

    @MainActor
    final class InputRecorder: RemoteCanvasInput {
        static let framebufferSize = CGSize(width: 1920, height: 1080)
        weak var canvas: RemoteCanvasUIView?
        var cursorPoint = CGPoint(x: 960, y: 540)
        private var moves = 0
        private var clicks = 0
        private var rightClicks = 0
        private var downs = 0
        private var ups = 0
        private var scrolls = 0
        private var maxViewDelta: CGFloat = 0

        func movePointer(viewDelta: CGPoint, viewSize: CGSize, zoomScale: CGFloat) {
            let delta = RemoteGeometry.framebufferDelta(
                fromViewDelta: viewDelta,
                framebufferSize: Self.framebufferSize,
                viewSize: viewSize,
                zoomScale: zoomScale
            )
            cursorPoint = RemoteGeometry.clamp(
                CGPoint(x: cursorPoint.x + delta.x, y: cursorPoint.y + delta.y),
                to: Self.framebufferSize
            )
            moves += 1
            maxViewDelta = max(maxViewDelta, hypot(viewDelta.x, viewDelta.y))
            publish()
        }

        func mouseDown(_ button: VNCMouseButton) { downs += 1; publish() }
        func mouseUp(_ button: VNCMouseButton) { ups += 1; publish() }
        func click(_ button: VNCMouseButton, count: Int) {
            if button == .right { rightClicks += count } else { clicks += count }
            publish()
        }
        func scroll(_ wheel: VNCMouseWheel, steps: UInt32) { scrolls += Int(steps); publish() }

        func publish() {
            canvas?.accessibilityValue = "moves=\(moves),clicks=\(clicks),rightClicks=\(rightClicks),downs=\(downs),ups=\(ups),scrolls=\(scrolls),maxDelta=\(maxViewDelta)"
        }
    }
}
#endif
