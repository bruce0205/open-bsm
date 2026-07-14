import AppKit
@preconcurrency import InputMethodKit

@MainActor
final class CandidateBar {
    private enum Metrics {
        static let height: CGFloat = 34
        static let itemHeight: CGFloat = 28
        static let itemSpacing: CGFloat = 8
        static let horizontalInset: CGFloat = 8
        static let verticalInset: CGFloat = 3
        static let minimumItemWidth: CGFloat = 72
        static let maximumItemWidth: CGFloat = 180
        static let maximumBarWidth: CGFloat = 900
        static let pageButtonWidth: CGFloat = 22
        static let minimumPageLabelWidth: CGFloat = 36
        static let dividerWidth: CGFloat = 1
        static let dividerInset: CGFloat = 8
        static let anchorGap: CGFloat = 6
        static let screenInset: CGFloat = 8
    }

    private struct Layout {
        let size: NSSize
        let itemWidths: [CGFloat]
        let pageLabelWidth: CGFloat
    }

    private let panel: CandidatePanel
    private let backgroundView: CandidateBackgroundView
    private let candidateViews: [CandidateItemView]
    private let dividerView: CandidateDividerView
    private let previousPageButton: CandidatePageButton
    private let pageLabel: NSTextField
    private let nextPageButton: CandidatePageButton

    private weak var owner: AnyObject?
    private var inputClient: (any IMKTextInput)?
    private var onCandidateSelected: ((Int) -> Void)?
    private var onPageChanged: ((Int) -> Void)?
    private var currentPage = 0
    private var totalPages = 0
    private var lastAnchor: (rect: NSRect, isHorizontal: Bool)?
    private var revision = 0

    init() {
        let panel = CandidatePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let backgroundView = CandidateBackgroundView(frame: .zero)
        let candidateViews = (0..<9).map(CandidateItemView.init(index:))
        let dividerView = CandidateDividerView(frame: .zero)
        let previousPageButton = CandidatePageButton(
            symbolName: "chevron.left",
            accessibilityLabel: "上一頁"
        )
        let pageLabel = NSTextField(labelWithString: "")
        let nextPageButton = CandidatePageButton(
            symbolName: "chevron.right",
            accessibilityLabel: "下一頁"
        )

        backgroundView.autoresizingMask = [.width, .height]

        pageLabel.alignment = .center
        pageLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        pageLabel.textColor = NSColor.white.withAlphaComponent(0.58)
        pageLabel.lineBreakMode = .byClipping
        pageLabel.setAccessibilityLabel("分頁")

        for candidateView in candidateViews {
            backgroundView.addSubview(candidateView)
        }
        backgroundView.addSubview(dividerView)
        backgroundView.addSubview(previousPageButton)
        backgroundView.addSubview(pageLabel)
        backgroundView.addSubview(nextPageButton)

        panel.contentView = backgroundView
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.canHide = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.animationBehavior = .none
        panel.collectionBehavior = [
            .canJoinAllApplications,
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle,
        ]

        self.panel = panel
        self.backgroundView = backgroundView
        self.candidateViews = candidateViews
        self.dividerView = dividerView
        self.previousPageButton = previousPageButton
        self.pageLabel = pageLabel
        self.nextPageButton = nextPageButton

        for candidateView in candidateViews {
            candidateView.onPress = { [weak self] index in
                self?.onCandidateSelected?(index)
            }
        }
        previousPageButton.onPress = { [weak self] in
            self?.onPageChanged?(-1)
        }
        nextPageButton.onPress = { [weak self] in
            self?.onPageChanged?(1)
        }
    }

    func show(
        owner: AnyObject,
        candidates: [String],
        selectedIndex: Int,
        currentPage: Int,
        totalPages: Int,
        client: any IMKTextInput,
        onCandidateSelected: @escaping (Int) -> Void,
        onPageChanged: @escaping (Int) -> Void
    ) {
        if self.owner !== owner {
            lastAnchor = nil
            panel.orderOut(nil)
        }

        self.owner = owner
        inputClient = client
        self.onCandidateSelected = onCandidateSelected
        self.onPageChanged = onPageChanged
        self.currentPage = currentPage
        self.totalPages = totalPages
        revision += 1

        for (index, candidateView) in candidateViews.enumerated() {
            if candidates.indices.contains(index) {
                candidateView.configure(
                    candidate: candidates[index],
                    isSelected: index == selectedIndex
                )
                candidateView.isHidden = false
            } else {
                candidateView.isHidden = true
            }
        }

        let showsPagination = totalPages > 1
        dividerView.isHidden = !showsPagination
        previousPageButton.isHidden = !showsPagination
        pageLabel.isHidden = !showsPagination
        nextPageButton.isHidden = !showsPagination

        if showsPagination {
            pageLabel.stringValue = "\(currentPage) / \(totalPages)"
            pageLabel.setAccessibilityValue("第 \(currentPage) 頁，共 \(totalPages) 頁")
            previousPageButton.isEnabled = currentPage > 1
            nextPageButton.isEnabled = currentPage < totalPages
            previousPageButton.toolTip = "上一頁（Fn + ↑）"
            nextPageButton.toolTip = "下一頁（Fn + ↓）"
        }

        synchronizeFrame()

        let expectedRevision = revision
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, self.revision == expectedRevision else { return }
            self.synchronizeFrame()
        }
    }

    func hide(owner: AnyObject) {
        guard self.owner === owner else { return }

        revision += 1
        self.owner = nil
        inputClient = nil
        onCandidateSelected = nil
        onPageChanged = nil
        currentPage = 0
        totalPages = 0
        lastAnchor = nil
        panel.orderOut(nil)
    }

    private func synchronizeFrame() {
        guard owner != nil,
              let inputClient,
              let anchor = inputAnchor(for: inputClient) ?? lastAnchor,
              let screen = screen(containing: anchor.rect) else {
            return
        }

        lastAnchor = anchor
        panel.level = NSWindow.Level(rawValue: Int(inputClient.windowLevel()) + 1)

        let layout = makeLayout(for: screen)
        let origin = panelOrigin(
            size: layout.size,
            anchor: anchor,
            screen: screen
        )
        panel.setFrame(
            NSRect(origin: origin, size: layout.size),
            display: true
        )
        layoutContent(using: layout)
        panel.orderFrontRegardless()
    }

    private func inputAnchor(
        for inputClient: any IMKTextInput
    ) -> (rect: NSRect, isHorizontal: Bool)? {
        var lineRect = NSRect.zero
        let attributes = inputClient.attributes(
            forCharacterIndex: 0,
            lineHeightRectangle: &lineRect
        )
        let rect = lineRect.standardized

        guard rect.origin.x.isFinite,
              rect.origin.y.isFinite,
              rect.height.isFinite,
              rect.height > 0 else {
            return nil
        }

        let isHorizontal =
            (attributes?[IMKTextOrientationName] as? NSNumber)?.boolValue ?? true
        return (rect, isHorizontal)
    }

    private func makeLayout(for screen: NSScreen) -> Layout {
        let visibleCandidateViews = candidateViews.filter { !$0.isHidden }
        var itemWidths = visibleCandidateViews.map {
            min(
                max($0.preferredWidth, Metrics.minimumItemWidth),
                Metrics.maximumItemWidth
            )
        }
        let itemSpacing = Metrics.itemSpacing * CGFloat(max(itemWidths.count - 1, 0))

        let pageLabelWidth: CGFloat
        let paginationWidth: CGFloat
        if totalPages > 1 {
            let maximumPageText = "\(totalPages) / \(totalPages)" as NSString
            let textWidth = ceil(
                maximumPageText.size(withAttributes: [.font: pageLabel.font!]).width
            )
            pageLabelWidth = max(Metrics.minimumPageLabelWidth, textWidth + 8)
            paginationWidth = Metrics.dividerInset
                + Metrics.dividerWidth
                + Metrics.dividerInset
                + Metrics.pageButtonWidth
                + pageLabelWidth
                + Metrics.pageButtonWidth
        } else {
            pageLabelWidth = 0
            paginationWidth = 0
        }

        let fixedWidth = Metrics.horizontalInset * 2 + itemSpacing + paginationWidth
        let maximumWidth = max(
            1,
            min(
                Metrics.maximumBarWidth,
                screen.visibleFrame.width - Metrics.screenInset * 2
            )
        )
        let availableItemWidth = max(maximumWidth - fixedWidth, 1)
        let naturalItemWidth = itemWidths.reduce(0, +)

        if naturalItemWidth > availableItemWidth, !itemWidths.isEmpty {
            let minimumItemWidth = min(
                Metrics.minimumItemWidth,
                availableItemWidth / CGFloat(itemWidths.count)
            )
            let minimumTotal = minimumItemWidth * CGFloat(itemWidths.count)
            let flexibleTotal = itemWidths.reduce(0) {
                $0 + max($1 - minimumItemWidth, 0)
            }
            let availableFlexibleWidth = max(availableItemWidth - minimumTotal, 0)
            let scale = flexibleTotal > 0
                ? min(availableFlexibleWidth / flexibleTotal, 1)
                : 0

            itemWidths = itemWidths.map {
                minimumItemWidth + max($0 - minimumItemWidth, 0) * scale
            }
        }

        let width = min(
            fixedWidth + itemWidths.reduce(0, +),
            maximumWidth
        )
        return Layout(
            size: NSSize(width: ceil(width), height: Metrics.height),
            itemWidths: itemWidths,
            pageLabelWidth: pageLabelWidth
        )
    }

    private func layoutContent(using layout: Layout) {
        var x = Metrics.horizontalInset
        let visibleCandidateViews = candidateViews.filter { !$0.isHidden }

        for (index, candidateView) in visibleCandidateViews.enumerated() {
            candidateView.frame = NSRect(
                x: x,
                y: Metrics.verticalInset,
                width: layout.itemWidths[index],
                height: Metrics.itemHeight
            )
            x += layout.itemWidths[index]
            if index < visibleCandidateViews.count - 1 {
                x += Metrics.itemSpacing
            }
        }

        guard totalPages > 1 else { return }

        x += Metrics.dividerInset
        dividerView.frame = NSRect(
            x: x,
            y: 8,
            width: Metrics.dividerWidth,
            height: Metrics.height - 16
        )
        x += Metrics.dividerWidth + Metrics.dividerInset

        previousPageButton.frame = NSRect(
            x: x,
            y: (Metrics.height - Metrics.pageButtonWidth) / 2,
            width: Metrics.pageButtonWidth,
            height: Metrics.pageButtonWidth
        )
        x += Metrics.pageButtonWidth

        pageLabel.frame = NSRect(
            x: x,
            y: Metrics.verticalInset,
            width: layout.pageLabelWidth,
            height: Metrics.itemHeight
        )
        x += layout.pageLabelWidth

        nextPageButton.frame = NSRect(
            x: x,
            y: (Metrics.height - Metrics.pageButtonWidth) / 2,
            width: Metrics.pageButtonWidth,
            height: Metrics.pageButtonWidth
        )
    }

    private func panelOrigin(
        size: NSSize,
        anchor: (rect: NSRect, isHorizontal: Bool),
        screen: NSScreen
    ) -> NSPoint {
        let visibleFrame = screen.visibleFrame.insetBy(
            dx: Metrics.screenInset,
            dy: Metrics.screenInset
        )
        var origin: NSPoint

        if anchor.isHorizontal {
            let belowY = anchor.rect.minY - Metrics.anchorGap - size.height
            let y = belowY >= visibleFrame.minY
                ? belowY
                : anchor.rect.maxY + Metrics.anchorGap
            origin = NSPoint(x: anchor.rect.minX, y: y)
        } else {
            let rightX = anchor.rect.maxX + Metrics.anchorGap
            let x = rightX + size.width <= visibleFrame.maxX
                ? rightX
                : anchor.rect.minX - Metrics.anchorGap - size.width
            origin = NSPoint(x: x, y: anchor.rect.maxY - size.height)
        }

        origin.x = min(
            max(origin.x, visibleFrame.minX),
            visibleFrame.maxX - size.width
        )
        origin.y = min(
            max(origin.y, visibleFrame.minY),
            visibleFrame.maxY - size.height
        )
        return origin
    }

    private func screen(containing rect: NSRect) -> NSScreen? {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.first { NSPointInRect(center, $0.frame) }
            ?? NSScreen.screens.first { $0.frame.intersects(rect) }
            ?? NSScreen.main
    }
}

@MainActor
private final class CandidatePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class CandidateBackgroundView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(
            srgbRed: 42.0 / 255.0,
            green: 42.0 / 255.0,
            blue: 40.0 / 255.0,
            alpha: 1
        ).cgColor
        layer?.cornerRadius = 7
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
private final class CandidateDividerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        updateColor()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColor()
    }

    private func updateColor() {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
    }
}

@MainActor
private final class CandidateTextField: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
private final class CandidateImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
private final class CandidateItemView: NSControl {
    private let shortcutLabel: CandidateTextField
    private let candidateLabel: CandidateTextField
    private var trackingAreaReference: NSTrackingArea?
    private var isCandidateSelected = false
    private var isHovered = false
    private var isPressed = false

    let index: Int
    var onPress: ((Int) -> Void)?

    init(index: Int) {
        self.index = index
        shortcutLabel = CandidateTextField(labelWithString: "\(index + 1)")
        candidateLabel = CandidateTextField(labelWithString: "")
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous

        shortcutLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        shortcutLabel.alignment = .right
        shortcutLabel.lineBreakMode = .byClipping

        candidateLabel.font = .systemFont(ofSize: 21, weight: .regular)
        candidateLabel.lineBreakMode = .byTruncatingTail
        candidateLabel.maximumNumberOfLines = 1
        shortcutLabel.setAccessibilityElement(false)
        candidateLabel.setAccessibilityElement(false)

        addSubview(shortcutLabel)
        addSubview(candidateLabel)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var preferredWidth: CGFloat {
        let shortcutWidth = ceil(shortcutLabel.intrinsicContentSize.width)
        let candidateWidth = ceil(candidateLabel.intrinsicContentSize.width)
        return shortcutWidth + 7 + candidateWidth + 16
    }

    func configure(candidate: String, isSelected: Bool) {
        candidateLabel.stringValue = candidate
        isCandidateSelected = isSelected
        toolTip = candidate
        setAccessibilityLabel("候選字 \(index + 1)：\(candidate)")
        setAccessibilityValue(candidate)
        setAccessibilitySelected(isSelected)
        updateAppearance()
        needsLayout = true
    }

    override func layout() {
        super.layout()

        let shortcutWidth = ceil(shortcutLabel.intrinsicContentSize.width)
        shortcutLabel.frame = NSRect(
            x: 8,
            y: 0,
            width: shortcutWidth,
            height: bounds.height
        )
        let candidateX = shortcutLabel.frame.maxX + 7
        candidateLabel.frame = NSRect(
            x: candidateX,
            y: 0,
            width: max(bounds.width - candidateX - 8, 0),
            height: bounds.height
        )
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaReference = trackingArea
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        updateAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        updateAppearance()
    }

    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        isPressed = bounds.contains(location)
        updateAppearance()
    }

    override func mouseUp(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let shouldPerformAction = isPressed && bounds.contains(location)
        isPressed = false
        updateAppearance()
        if shouldPerformAction {
            onPress?(index)
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        let backgroundColor: NSColor
        if isCandidateSelected {
            backgroundColor = NSColor(
                srgbRed: 59.0 / 255.0,
                green: 143.0 / 255.0,
                blue: 229.0 / 255.0,
                alpha: 1
            )
        } else if isPressed {
            backgroundColor = NSColor.white.withAlphaComponent(0.12)
        } else if isHovered {
            backgroundColor = NSColor.white.withAlphaComponent(0.07)
        } else {
            backgroundColor = .clear
        }

        shortcutLabel.textColor = isCandidateSelected
            ? NSColor.white.withAlphaComponent(0.72)
            : NSColor.white.withAlphaComponent(0.45)
        candidateLabel.textColor = isCandidateSelected
            ? .white
            : NSColor.white.withAlphaComponent(0.82)
        candidateLabel.font = .systemFont(
            ofSize: 21,
            weight: isCandidateSelected ? .medium : .regular
        )
        layer?.backgroundColor = backgroundColor.cgColor
    }
}

@MainActor
private final class CandidatePageButton: NSControl {
    private let imageView: CandidateImageView
    private var trackingAreaReference: NSTrackingArea?
    private var isHovered = false
    private var isPressed = false
    var onPress: (() -> Void)?

    init(symbolName: String, accessibilityLabel: String) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: accessibilityLabel
        )?.withSymbolConfiguration(configuration)
        imageView = CandidateImageView(image: image ?? NSImage())
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.cornerCurve = .continuous
        imageView.imageScaling = .scaleNone
        imageView.setAccessibilityElement(false)
        addSubview(imageView)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(accessibilityLabel)
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isEnabled: Bool {
        didSet {
            if !isEnabled {
                isHovered = false
                isPressed = false
            }
            updateAppearance()
        }
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaReference = trackingArea
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { isEnabled }

    override func mouseEntered(with event: NSEvent) {
        guard isEnabled else { return }
        isHovered = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        updateAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isPressed = true
        updateAppearance()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled else { return }
        let location = convert(event.locationInWindow, from: nil)
        isPressed = bounds.contains(location)
        updateAppearance()
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled else { return }
        let location = convert(event.locationInWindow, from: nil)
        let shouldPerformAction = isPressed && bounds.contains(location)
        isPressed = false
        updateAppearance()
        if shouldPerformAction {
            onPress?()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        let backgroundColor: NSColor
        if !isEnabled {
            backgroundColor = .clear
        } else if isPressed {
            backgroundColor = NSColor.white.withAlphaComponent(0.12)
        } else if isHovered {
            backgroundColor = NSColor.white.withAlphaComponent(0.07)
        } else {
            backgroundColor = .clear
        }

        imageView.contentTintColor = isEnabled
            ? NSColor.white.withAlphaComponent(0.55)
            : NSColor.white.withAlphaComponent(0.25)
        layer?.backgroundColor = backgroundColor.cgColor
    }
}
