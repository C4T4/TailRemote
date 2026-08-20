import CoreGraphics
import RoyalVNCKit
import SwiftUI
import UIKit

struct RemoteCanvasView: UIViewRepresentable {
    @ObservedObject var session: VNCSession

    func makeUIView(context: Context) -> RemoteCanvasUIView {
        let view = RemoteCanvasUIView()
        view.session = session
        return view
    }

    func updateUIView(_ view: RemoteCanvasUIView, context: Context) {
        view.session = session
        view.update(
            image: session.framebufferImage,
            framebufferSize: session.framebufferSize,
            cursorPoint: session.cursorPoint
        )
    }
}

@MainActor
final class RemoteCanvasUIView: UIView, UIGestureRecognizerDelegate {
    var session: VNCSession?

    private let imageLayer = CALayer()
    private let cursorLayer = CAShapeLayer()
    private var framebufferSize: CGSize = .zero
    private var cursorPoint: CGPoint = .zero
    private var previousDragLocation: CGPoint?
    private var zoomScale = RemoteGeometry.minimumZoomScale
    private var panOffset: CGPoint = .zero
    private var isPinching = false

    private var interactionViewport: CGRect {
        let horizontalInset = min(56, bounds.width * 0.15)
        let verticalInset = min(88, bounds.height * 0.15)
        return bounds.insetBy(dx: horizontalInset, dy: verticalInset)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isMultipleTouchEnabled = true

        imageLayer.contentsGravity = .resizeAspect
        imageLayer.magnificationFilter = .linear
        imageLayer.minificationFilter = .trilinear
        layer.addSublayer(imageLayer)

        cursorLayer.bounds = CGRect(x: 0, y: 0, width: 14, height: 14)
        cursorLayer.path = UIBezierPath(ovalIn: cursorLayer.bounds).cgPath
        cursorLayer.fillColor = UIColor.white.withAlphaComponent(0.88).cgColor
        cursorLayer.strokeColor = UIColor.black.withAlphaComponent(0.55).cgColor
        cursorLayer.lineWidth = 1.5
        cursorLayer.shadowColor = UIColor.black.cgColor
        cursorLayer.shadowOpacity = 0.45
        cursorLayer.shadowRadius = 3
        cursorLayer.shadowOffset = .zero
        layer.addSublayer(cursorLayer)

        installGestures()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutRemoteContent()
    }

    func update(image: CGImage?, framebufferSize: CGSize, cursorPoint: CGPoint) {
        imageLayer.contents = image
        if self.framebufferSize != framebufferSize, self.framebufferSize != .zero {
            zoomScale = RemoteGeometry.minimumZoomScale
            panOffset = .zero
        }
        self.framebufferSize = framebufferSize
        self.cursorPoint = cursorPoint
        layoutRemoteContent()
    }

    private func layoutRemoteContent() {
        let baseImageRect = RemoteGeometry.aspectFitRect(imageSize: framebufferSize, in: bounds)
        panOffset = RemoteGeometry.clampedPanOffset(
            panOffset,
            baseRect: baseImageRect,
            viewportRect: interactionViewport,
            zoomScale: zoomScale
        )
        let imageRect = RemoteGeometry.zoomedRect(
            baseRect: baseImageRect,
            zoomScale: zoomScale,
            panOffset: panOffset
        )
        imageLayer.frame = imageRect

        guard framebufferSize.width > 0, framebufferSize.height > 0 else {
            cursorLayer.isHidden = true
            return
        }

        cursorLayer.isHidden = false
        let x = imageRect.minX + (cursorPoint.x / framebufferSize.width) * imageRect.width
        let y = imageRect.minY + (cursorPoint.y / framebufferSize.height) * imageRect.height
        cursorLayer.position = CGPoint(x: x, y: y)
    }

    private func installGestures() {
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTap.numberOfTapsRequired = 1
        singleTap.numberOfTouchesRequired = 1

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.numberOfTouchesRequired = 1
        singleTap.require(toFail: doubleTap)

        let rightClick = UITapGestureRecognizer(target: self, action: #selector(handleRightClick))
        rightClick.numberOfTapsRequired = 1
        rightClick.numberOfTouchesRequired = 2

        let move = UIPanGestureRecognizer(target: self, action: #selector(handleMove))
        move.minimumNumberOfTouches = 1
        move.maximumNumberOfTouches = 1

        let drag = UILongPressGestureRecognizer(target: self, action: #selector(handleDrag))
        drag.minimumPressDuration = 0.30
        drag.allowableMovement = 36
        move.require(toFail: drag)

        let scroll = UIPanGestureRecognizer(target: self, action: #selector(handleScroll))
        scroll.minimumNumberOfTouches = 2
        scroll.maximumNumberOfTouches = 2

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        pinch.delegate = self
        scroll.delegate = self

        [singleTap, doubleTap, rightClick, move, drag, scroll, pinch].forEach(addGestureRecognizer)
    }

    @objc private func handleSingleTap() {
        session?.click(.left)
    }

    @objc private func handleDoubleTap() {
        session?.click(.left, count: 2)
    }

    @objc private func handleRightClick() {
        session?.click(.right)
    }

    @objc private func handleMove(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .began || gesture.state == .changed else { return }
        let translation = gesture.translation(in: self)
        gesture.setTranslation(.zero, in: self)
        moveRemotePointer(by: translation)
    }

    @objc private func handleDrag(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            previousDragLocation = gesture.location(in: self)
            session?.mouseDown(.left)
        case .changed:
            let location = gesture.location(in: self)
            if let previousDragLocation {
                moveRemotePointer(
                    by: CGPoint(
                        x: location.x - previousDragLocation.x,
                        y: location.y - previousDragLocation.y
                    )
                )
            }
            previousDragLocation = location
        case .ended, .cancelled, .failed:
            session?.mouseUp(.left)
            previousDragLocation = nil
        default:
            break
        }
    }

    @objc private func handleScroll(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .began || gesture.state == .changed else { return }
        let translation = gesture.translation(in: self)

        if isPinching {
            gesture.setTranslation(.zero, in: self)
            return
        }

        if zoomScale > RemoteGeometry.minimumZoomScale {
            let baseImageRect = RemoteGeometry.aspectFitRect(imageSize: framebufferSize, in: bounds)
            panOffset = RemoteGeometry.clampedPanOffset(
                CGPoint(x: panOffset.x + translation.x, y: panOffset.y + translation.y),
                baseRect: baseImageRect,
                viewportRect: interactionViewport,
                zoomScale: zoomScale
            )
            gesture.setTranslation(.zero, in: self)
            layoutRemoteContent()
            return
        }

        guard abs(translation.y) >= 10 else { return }
        let wheel: VNCMouseWheel = translation.y < 0 ? .down : .up
        let steps = UInt32(min(max(Int(abs(translation.y) / 10), 1), 6))
        session?.scroll(wheel, steps: steps)
        gesture.setTranslation(.zero, in: self)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            isPinching = true
        case .changed:
            let oldScale = zoomScale
            let newScale = RemoteGeometry.clampedZoomScale(oldScale * gesture.scale)
            let baseImageRect = RemoteGeometry.aspectFitRect(imageSize: framebufferSize, in: bounds)

            panOffset = RemoteGeometry.panOffsetKeepingFocalPointStable(
                currentOffset: panOffset,
                focalPoint: gesture.location(in: self),
                baseCenter: CGPoint(x: baseImageRect.midX, y: baseImageRect.midY),
                oldScale: oldScale,
                newScale: newScale
            )
            zoomScale = newScale
            panOffset = RemoteGeometry.clampedPanOffset(
                panOffset,
                baseRect: baseImageRect,
                viewportRect: interactionViewport,
                zoomScale: zoomScale
            )
            gesture.scale = 1
            layoutRemoteContent()
        case .ended, .cancelled, .failed:
            isPinching = false
            if zoomScale < 1.05 {
                zoomScale = RemoteGeometry.minimumZoomScale
                panOffset = .zero
                layoutRemoteContent()
            }
        default:
            break
        }
    }

    private func moveRemotePointer(by delta: CGPoint) {
        guard let session else { return }
        let baseImageRect = RemoteGeometry.aspectFitRect(imageSize: framebufferSize, in: bounds)
        session.movePointer(viewDelta: delta, viewSize: baseImageRect.size)
        cursorPoint = session.cursorPoint

        guard zoomScale > RemoteGeometry.minimumZoomScale,
              framebufferSize.width > 0,
              framebufferSize.height > 0 else {
            layoutRemoteContent()
            return
        }

        panOffset = RemoteGeometry.panOffsetFollowingCursor(
            normalizedCursorPoint: CGPoint(
                x: cursorPoint.x / framebufferSize.width,
                y: cursorPoint.y / framebufferSize.height
            ),
            currentOffset: panOffset,
            baseRect: baseImageRect,
            viewportRect: interactionViewport,
            zoomScale: zoomScale
        )
        layoutRemoteContent()
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        let pair = [gestureRecognizer, otherGestureRecognizer]
        return pair.contains { $0 is UIPinchGestureRecognizer }
            && pair.contains { $0 is UIPanGestureRecognizer }
    }
}
