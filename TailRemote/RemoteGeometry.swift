import CoreGraphics

enum RemoteGeometry {
    static let minimumZoomScale: CGFloat = 1
    static let maximumZoomScale: CGFloat = 4

    static func aspectFitRect(imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0,
              imageSize.height > 0,
              bounds.width > 0,
              bounds.height > 0 else {
            return .zero
        }

        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    static func framebufferDelta(
        fromViewDelta delta: CGPoint,
        framebufferSize: CGSize,
        viewSize: CGSize,
        sensitivity: CGFloat = 1.6
    ) -> CGPoint {
        guard framebufferSize.width > 0,
              framebufferSize.height > 0,
              viewSize.width > 0,
              viewSize.height > 0 else {
            return .zero
        }

        let scale = max(framebufferSize.width / viewSize.width, framebufferSize.height / viewSize.height)
        return CGPoint(x: delta.x * scale * sensitivity, y: delta.y * scale * sensitivity)
    }

    static func clamp(_ point: CGPoint, to size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return .zero }
        return CGPoint(
            x: min(max(point.x, 0), size.width - 1),
            y: min(max(point.y, 0), size.height - 1)
        )
    }

    static func clampedZoomScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minimumZoomScale), maximumZoomScale)
    }

    static func clampedPanOffset(
        _ offset: CGPoint,
        baseRect: CGRect,
        viewportRect: CGRect,
        zoomScale: CGFloat
    ) -> CGPoint {
        let scale = clampedZoomScale(zoomScale)
        let maximumX = max((baseRect.width * scale - viewportRect.width) / 2, 0)
        let maximumY = max((baseRect.height * scale - viewportRect.height) / 2, 0)

        return CGPoint(
            x: min(max(offset.x, -maximumX), maximumX),
            y: min(max(offset.y, -maximumY), maximumY)
        )
    }

    static func panOffsetFollowingCursor(
        normalizedCursorPoint: CGPoint,
        currentOffset: CGPoint,
        baseRect: CGRect,
        viewportRect: CGRect,
        zoomScale: CGFloat
    ) -> CGPoint {
        let imageRect = zoomedRect(
            baseRect: baseRect,
            zoomScale: zoomScale,
            panOffset: currentOffset
        )
        let cursor = CGPoint(
            x: imageRect.minX + normalizedCursorPoint.x * imageRect.width,
            y: imageRect.minY + normalizedCursorPoint.y * imageRect.height
        )
        var offset = currentOffset

        if cursor.x < viewportRect.minX {
            offset.x += viewportRect.minX - cursor.x
        } else if cursor.x > viewportRect.maxX {
            offset.x += viewportRect.maxX - cursor.x
        }

        if cursor.y < viewportRect.minY {
            offset.y += viewportRect.minY - cursor.y
        } else if cursor.y > viewportRect.maxY {
            offset.y += viewportRect.maxY - cursor.y
        }

        return clampedPanOffset(
            offset,
            baseRect: baseRect,
            viewportRect: viewportRect,
            zoomScale: zoomScale
        )
    }

    static func panOffsetKeepingFocalPointStable(
        currentOffset: CGPoint,
        focalPoint: CGPoint,
        baseCenter: CGPoint,
        oldScale: CGFloat,
        newScale: CGFloat
    ) -> CGPoint {
        guard oldScale > 0 else { return currentOffset }
        let scaleChange = newScale / oldScale

        return CGPoint(
            x: focalPoint.x - baseCenter.x
                - (focalPoint.x - baseCenter.x - currentOffset.x) * scaleChange,
            y: focalPoint.y - baseCenter.y
                - (focalPoint.y - baseCenter.y - currentOffset.y) * scaleChange
        )
    }

    static func zoomedRect(
        baseRect: CGRect,
        zoomScale: CGFloat,
        panOffset: CGPoint
    ) -> CGRect {
        let scale = clampedZoomScale(zoomScale)
        let size = CGSize(width: baseRect.width * scale, height: baseRect.height * scale)

        return CGRect(
            x: baseRect.midX + panOffset.x - size.width / 2,
            y: baseRect.midY + panOffset.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
