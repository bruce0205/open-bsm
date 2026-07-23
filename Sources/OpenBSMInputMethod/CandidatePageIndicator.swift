import AppKit
@preconcurrency import InputMethodKit
import OpenBSMCore

enum CandidateBarTheme: String {
    case dark
    case light

    private static let defaultsKey = "CandidateBarTheme"

    static var current: Self {
        guard let rawValue = UserDefaults.standard.string(forKey: defaultsKey),
              let theme = Self(rawValue: rawValue) else {
            return .dark
        }
        return theme
    }

    static func select(_ theme: Self) {
        UserDefaults.standard.set(theme.rawValue, forKey: defaultsKey)
    }

    var tintColor: NSColor {
        switch self {
        case .dark:
            NSColor(
                srgbRed: 28.0 / 255.0,
                green: 28.0 / 255.0,
                blue: 26.0 / 255.0,
                alpha: 0.90
            )
        case .light:
            NSColor(
                srgbRed: 248.0 / 255.0,
                green: 247.0 / 255.0,
                blue: 243.0 / 255.0,
                alpha: 0.94
            )
        }
    }

    var selectedBackgroundColor: NSColor {
        switch self {
        case .dark:
            NSColor(
                srgbRed: 55.0 / 255.0,
                green: 138.0 / 255.0,
                blue: 221.0 / 255.0,
                alpha: 1
            )
        case .light:
            NSColor(
                srgbRed: 25.0 / 255.0,
                green: 90.0 / 255.0,
                blue: 145.0 / 255.0,
                alpha: 1
            )
        }
    }

    var primaryTextColor: NSColor {
        self == .dark ? NSColor.white.withAlphaComponent(0.76) : NSColor(
            srgbRed: 30.0 / 255.0,
            green: 41.0 / 255.0,
            blue: 51.0 / 255.0,
            alpha: 1
        )
    }

    var secondaryTextColor: NSColor {
        self == .dark ? NSColor.white.withAlphaComponent(0.58) : NSColor(
            srgbRed: 107.0 / 255.0,
            green: 114.0 / 255.0,
            blue: 128.0 / 255.0,
            alpha: 1
        )
    }

    var mutedTextColor: NSColor {
        self == .dark ? NSColor.white.withAlphaComponent(0.52) : NSColor(
            srgbRed: 107.0 / 255.0,
            green: 114.0 / 255.0,
            blue: 128.0 / 255.0,
            alpha: 0.82
        )
    }

    var shortcutTextColor: NSColor {
        self == .dark ? NSColor.white.withAlphaComponent(0.68) : secondaryTextColor
    }

    var keycapTextColor: NSColor {
        self == .dark ? NSColor.white.withAlphaComponent(0.88) : primaryTextColor
    }

    var navigationIconColor: NSColor {
        self == .dark ? NSColor.white.withAlphaComponent(0.55) : secondaryTextColor
    }

    var subtleFillColor: NSColor {
        self == .dark ? NSColor.white.withAlphaComponent(0.10) : NSColor(
            srgbRed: 30.0 / 255.0,
            green: 41.0 / 255.0,
            blue: 51.0 / 255.0,
            alpha: 0.08
        )
    }

    var hoverFillColor: NSColor {
        self == .dark ? NSColor.white.withAlphaComponent(0.07) : NSColor(
            srgbRed: 30.0 / 255.0,
            green: 41.0 / 255.0,
            blue: 51.0 / 255.0,
            alpha: 0.06
        )
    }

    var pressedFillColor: NSColor {
        self == .dark ? NSColor.white.withAlphaComponent(0.12) : NSColor(
            srgbRed: 30.0 / 255.0,
            green: 41.0 / 255.0,
            blue: 51.0 / 255.0,
            alpha: 0.10
        )
    }
}

@MainActor
final class CandidateBar {
    private enum Metrics {
        static let height: CGFloat = 52
        static let itemHeight: CGFloat = 36
        static let itemSpacing: CGFloat = 6
        static let horizontalInset: CGFloat = 8
        static let verticalInset: CGFloat = 8
        static let minimumCompressedItemWidth: CGFloat = 78
        static let maximumItemWidth: CGFloat = 180
        static let maximumBarWidth: CGFloat = 900
        static let pageButtonWidth: CGFloat = 32
        static let pageNavigationSpacing: CGFloat = 6
        static let minimumPageLabelWidth: CGFloat = 33
        static let anchorGap: CGFloat = 6
        static let screenInset: CGFloat = 8
        static let reverseLookupWidth: CGFloat = 374
        static let reverseLookupHeight: CGFloat = 52
        static let widthIndicatorWidth: CGFloat = 22
        static let widthIndicatorSpacing: CGFloat = 6
    }

    private struct Layout {
        let size: NSSize
        let itemWidths: [CGFloat]
        let pageLabelWidth: CGFloat
    }

    private let panel: CandidatePanel
    private let backgroundView: CandidateBackgroundView
    private let candidateViews: [CandidateItemView]
    private let previousPageButton: CandidatePageButton
    private let pageLabel: NSTextField
    private let widthIndicatorLabel: NSTextField
    private let nextPageButton: CandidatePageButton
    private let reverseLookupView: ReverseLookupView

    private weak var owner: AnyObject?
    private var inputClient: (any IMKTextInput)?
    private var onCandidateSelected: ((Int) -> Void)?
    private var onPageChanged: ((Int) -> Void)?
    private var currentPage = 0
    private var totalPages = 0
    private var displaysPagination = false
    private var isShowingReverseLookup = false
    private var lastAnchor: (rect: NSRect, isHorizontal: Bool)?
    private var revision = 0

    private var theme: CandidateBarTheme = .current {
        didSet {
            backgroundView.apply(theme: theme)
            candidateViews.forEach { $0.apply(theme: theme) }
            previousPageButton.apply(theme: theme)
            nextPageButton.apply(theme: theme)
            pageLabel.textColor = theme.secondaryTextColor
            widthIndicatorLabel.textColor = theme.mutedTextColor
            reverseLookupView.apply(theme: theme)
        }
    }

    init() {
        let panel = CandidatePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let backgroundView = CandidateBackgroundView(frame: .zero)
        let candidateViews = (0..<9).map(CandidateItemView.init(index:))
        let previousPageButton = CandidatePageButton(
            symbolName: "chevron.left",
            accessibilityLabel: "上一頁"
        )
        let pageLabel = NSTextField(labelWithString: "")
        let widthIndicatorLabel = NSTextField(labelWithString: "全")
        let nextPageButton = CandidatePageButton(
            symbolName: "chevron.right",
            accessibilityLabel: "下一頁"
        )
        let reverseLookupView = ReverseLookupView(frame: .zero)

        backgroundView.autoresizingMask = [.width, .height]

        pageLabel.alignment = .center
        pageLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        pageLabel.textColor = theme.secondaryTextColor
        pageLabel.lineBreakMode = .byClipping
        pageLabel.setAccessibilityLabel("分頁")

        widthIndicatorLabel.alignment = .center
        widthIndicatorLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        widthIndicatorLabel.textColor = theme.mutedTextColor
        widthIndicatorLabel.isHidden = true
        widthIndicatorLabel.setAccessibilityLabel("全型模式")

        for candidateView in candidateViews {
            backgroundView.addSubview(candidateView)
        }
        backgroundView.addSubview(pageLabel)
        backgroundView.addSubview(widthIndicatorLabel)
        backgroundView.addSubview(previousPageButton)
        backgroundView.addSubview(nextPageButton)
        backgroundView.addSubview(reverseLookupView)
        reverseLookupView.isHidden = true

        backgroundView.apply(theme: theme)

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
        self.previousPageButton = previousPageButton
        self.pageLabel = pageLabel
        self.widthIndicatorLabel = widthIndicatorLabel
        self.nextPageButton = nextPageButton
        self.reverseLookupView = reverseLookupView

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
        reverseLookupView.onPageChanged = { [weak self] offset in
            self?.onPageChanged?(offset)
        }
    }

    func show(
        owner: AnyObject,
        candidates: [String],
        selectedIndex: Int,
        currentPage: Int,
        totalPages: Int,
        characterWidth: CharacterWidth,
        client: any IMKTextInput,
        onCandidateSelected: @escaping (Int) -> Void,
        onPageChanged: @escaping (Int) -> Void
    ) {
        selectTheme(.current)

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
        displaysPagination = totalPages > 1
        isShowingReverseLookup = false
        reverseLookupView.isHidden = true
        widthIndicatorLabel.isHidden = characterWidth != .fullWidth
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

        previousPageButton.isHidden = !displaysPagination
        pageLabel.isHidden = !displaysPagination
        nextPageButton.isHidden = !displaysPagination

        if displaysPagination {
            pageLabel.stringValue = "\(currentPage)/\(totalPages)"
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

    func showReverseLookup(
        owner: AnyObject,
        character: String,
        code: String?,
        currentPage: Int,
        totalPages: Int,
        client: any IMKTextInput,
        onPageChanged: @escaping (Int) -> Void
    ) {
        selectTheme(.current)

        if self.owner !== owner {
            lastAnchor = nil
            panel.orderOut(nil)
        }

        self.owner = owner
        inputClient = client
        onCandidateSelected = nil
        self.onPageChanged = onPageChanged
        self.currentPage = currentPage
        self.totalPages = totalPages
        displaysPagination = false
        isShowingReverseLookup = true
        widthIndicatorLabel.isHidden = true
        revision += 1

        for candidateView in candidateViews {
            candidateView.isHidden = true
        }
        previousPageButton.isHidden = true
        pageLabel.isHidden = true
        nextPageButton.isHidden = true
        reverseLookupView.configure(
            character: character,
            code: code,
            currentPage: currentPage,
            totalPages: totalPages
        )
        reverseLookupView.isHidden = false

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
        displaysPagination = false
        isShowingReverseLookup = false
        reverseLookupView.isHidden = true
        widthIndicatorLabel.isHidden = true
        lastAnchor = nil
        panel.orderOut(nil)
    }

    func selectTheme(_ theme: CandidateBarTheme) {
        self.theme = theme
    }

    func selectCharacterWidth(_ width: CharacterWidth) {
        widthIndicatorLabel.isHidden = width != .fullWidth || isShowingReverseLookup
        guard owner != nil else { return }
        synchronizeFrame()
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
        if isShowingReverseLookup {
            return Layout(
                size: NSSize(
                    width: Metrics.reverseLookupWidth,
                    height: Metrics.reverseLookupHeight
                ),
                itemWidths: [],
                pageLabelWidth: 0
            )
        }

        let visibleCandidateViews = candidateViews.filter { !$0.isHidden }
        var itemWidths = visibleCandidateViews.map {
            min($0.preferredWidth, Metrics.maximumItemWidth)
        }
        let itemSpacing = Metrics.itemSpacing * CGFloat(max(itemWidths.count - 1, 0))

        let pageLabelWidth: CGFloat
        let paginationWidth: CGFloat
        if displaysPagination {
            let maximumPageText = "\(totalPages)/\(totalPages)" as NSString
            let textWidth = ceil(
                maximumPageText.size(withAttributes: [.font: pageLabel.font!]).width
            )
            pageLabelWidth = max(Metrics.minimumPageLabelWidth, textWidth + 8)
            paginationWidth = Metrics.pageNavigationSpacing
                + pageLabelWidth
                + Metrics.pageButtonWidth * 2
        } else {
            pageLabelWidth = 0
            paginationWidth = 0
        }

        let widthIndicatorWidth = widthIndicatorLabel.isHidden
            ? 0
            : Metrics.widthIndicatorSpacing + Metrics.widthIndicatorWidth
        let fixedWidth = Metrics.horizontalInset * 2
            + itemSpacing
            + widthIndicatorWidth
            + paginationWidth
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
            let maximumMinimumItemWidth = min(
                Metrics.minimumCompressedItemWidth,
                availableItemWidth / CGFloat(itemWidths.count)
            )
            let minimumItemWidths = itemWidths.map {
                min($0, maximumMinimumItemWidth)
            }
            let minimumTotal = minimumItemWidths.reduce(0, +)
            let flexibleTotal = zip(itemWidths, minimumItemWidths).reduce(0) {
                $0 + $1.0 - $1.1
            }
            let availableFlexibleWidth = max(availableItemWidth - minimumTotal, 0)
            let scale = flexibleTotal > 0
                ? min(availableFlexibleWidth / flexibleTotal, 1)
                : 0

            itemWidths = zip(itemWidths, minimumItemWidths).map {
                $0.1 + ($0.0 - $0.1) * scale
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
        if isShowingReverseLookup {
            reverseLookupView.frame = backgroundView.bounds
            return
        }

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

        if !widthIndicatorLabel.isHidden {
            x += Metrics.widthIndicatorSpacing
            widthIndicatorLabel.frame = NSRect(
                x: x,
                y: Metrics.verticalInset,
                width: Metrics.widthIndicatorWidth,
                height: Metrics.itemHeight
            )
            x += Metrics.widthIndicatorWidth
        }

        guard displaysPagination else { return }
        x += Metrics.pageNavigationSpacing

        let pageLabelHeight = ceil(pageLabel.intrinsicContentSize.height)
        pageLabel.frame = NSRect(
            x: x,
            y: (Metrics.height - pageLabelHeight) / 2,
            width: layout.pageLabelWidth,
            height: pageLabelHeight
        )
        x += layout.pageLabelWidth

        previousPageButton.frame = NSRect(
            x: x,
            y: (Metrics.height - Metrics.pageButtonWidth) / 2,
            width: Metrics.pageButtonWidth,
            height: Metrics.pageButtonWidth
        )
        x += Metrics.pageButtonWidth

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
final class CharacterWidthIndicator {
    private enum Metrics {
        static let size = NSSize(width: 44, height: 44)
        static let anchorGap: CGFloat = 6
        static let screenInset: CGFloat = 8
        static let displayDuration = Duration.milliseconds(800)
    }

    private let panel: CandidatePanel
    private let backgroundView: CandidateBackgroundView
    private let label: NSTextField
    private var revision = 0

    init() {
        panel = CandidatePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        backgroundView = CandidateBackgroundView(
            frame: NSRect(origin: .zero, size: Metrics.size)
        )
        label = NSTextField(labelWithString: "")

        backgroundView.autoresizingMask = [.width, .height]
        label.frame = backgroundView.bounds
        label.autoresizingMask = [.width, .height]
        label.cell = VerticallyCenteredTextFieldCell(textCell: "")
        label.alignment = .center
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.setAccessibilityElement(true)
        label.setAccessibilityRole(.staticText)
        backgroundView.addSubview(label)

        panel.contentView = backgroundView
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.canHide = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        panel.collectionBehavior = [
            .canJoinAllApplications,
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle,
        ]
    }

    func show(width: CharacterWidth, client: any IMKTextInput) {
        let theme = CandidateBarTheme.current
        let text = width == .fullWidth ? "全" : "半"
        label.stringValue = text
        label.textColor = theme == .light
            ? theme.secondaryTextColor
            : theme.keycapTextColor
        label.setAccessibilityLabel(width == .fullWidth ? "全型模式" : "半型模式")
        backgroundView.apply(theme: theme)

        guard let anchor = inputAnchor(for: client),
              let screen = screen(containing: anchor.rect) else {
            return
        }

        revision += 1
        let expectedRevision = revision
        panel.level = NSWindow.Level(rawValue: Int(client.windowLevel()) + 1)
        panel.setFrame(
            NSRect(
                origin: panelOrigin(anchor: anchor, screen: screen),
                size: Metrics.size
            ),
            display: true
        )
        panel.orderFrontRegardless()

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Metrics.displayDuration)
            guard let self, self.revision == expectedRevision else { return }
            self.panel.orderOut(nil)
        }
    }

    func hide() {
        revision += 1
        panel.orderOut(nil)
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

    private func panelOrigin(
        anchor: (rect: NSRect, isHorizontal: Bool),
        screen: NSScreen
    ) -> NSPoint {
        let visibleFrame = screen.visibleFrame.insetBy(
            dx: Metrics.screenInset,
            dy: Metrics.screenInset
        )
        var origin: NSPoint

        if anchor.isHorizontal {
            let belowY = anchor.rect.minY - Metrics.anchorGap - Metrics.size.height
            let y = belowY >= visibleFrame.minY
                ? belowY
                : anchor.rect.maxY + Metrics.anchorGap
            origin = NSPoint(x: anchor.rect.minX, y: y)
        } else {
            let rightX = anchor.rect.maxX + Metrics.anchorGap
            let x = rightX + Metrics.size.width <= visibleFrame.maxX
                ? rightX
                : anchor.rect.minX - Metrics.anchorGap - Metrics.size.width
            origin = NSPoint(x: x, y: anchor.rect.maxY - Metrics.size.height)
        }

        origin.x = min(
            max(origin.x, visibleFrame.minX),
            visibleFrame.maxX - Metrics.size.width
        )
        origin.y = min(
            max(origin.y, visibleFrame.minY),
            visibleFrame.maxY - Metrics.size.height
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
    private let blurView = NSVisualEffectView()
    private let tintView = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true

        blurView.frame = bounds
        blurView.autoresizingMask = [.width, .height]
        blurView.blendingMode = .behindWindow
        blurView.material = .underWindowBackground
        blurView.state = .active
        addSubview(blurView)

        tintView.frame = bounds
        tintView.autoresizingMask = [.width, .height]
        tintView.wantsLayer = true
        addSubview(tintView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(theme: CandidateBarTheme) {
        tintView.layer?.backgroundColor = theme.tintColor.cgColor
    }
}

@MainActor
private final class CandidateTextField: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
private final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var drawingRect = super.drawingRect(forBounds: rect)
        let textHeight = cellSize(forBounds: drawingRect).height
        guard textHeight < drawingRect.height else { return drawingRect }

        drawingRect.origin.y += (drawingRect.height - textHeight) / 2
        drawingRect.size.height = textHeight
        return drawingRect
    }
}

@MainActor
private final class CandidateImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
private final class CandidateItemView: NSControl {
    private enum Metrics {
        static let horizontalInset: CGFloat = 14
        static let shortcutSize: CGFloat = 18
        static let contentSpacing: CGFloat = 7
    }

    private let shortcutLabel: CandidateTextField
    private let candidateLabel: CandidateTextField
    private var trackingAreaReference: NSTrackingArea?
    private var isCandidateSelected = false
    private var isHovered = false
    private var isPressed = false
    private var theme: CandidateBarTheme = .current

    let index: Int
    var onPress: ((Int) -> Void)?

    init(index: Int) {
        self.index = index
        shortcutLabel = CandidateTextField(labelWithString: "\(index + 1)")
        candidateLabel = CandidateTextField(labelWithString: "")
        super.init(frame: .zero)

        shortcutLabel.cell = VerticallyCenteredTextFieldCell(
            textCell: shortcutLabel.stringValue
        )
        candidateLabel.cell = VerticallyCenteredTextFieldCell(
            textCell: candidateLabel.stringValue
        )

        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous

        shortcutLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        shortcutLabel.alignment = .center
        shortcutLabel.lineBreakMode = .byClipping
        shortcutLabel.wantsLayer = true
        shortcutLabel.layer?.cornerRadius = Metrics.shortcutSize / 2
        shortcutLabel.layer?.cornerCurve = .continuous
        shortcutLabel.layer?.masksToBounds = true

        candidateLabel.font = .systemFont(ofSize: 21, weight: .medium)
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
        let candidateWidth = ceil(
            candidateLabel.cell?.cellSize.width
                ?? candidateLabel.intrinsicContentSize.width
        )
        return Metrics.horizontalInset * 2
            + Metrics.shortcutSize
            + Metrics.contentSpacing
            + candidateWidth
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

    func apply(theme: CandidateBarTheme) {
        self.theme = theme
        updateAppearance()
    }

    override func layout() {
        super.layout()

        shortcutLabel.frame = NSRect(
            x: Metrics.horizontalInset,
            y: (bounds.height - Metrics.shortcutSize) / 2,
            width: Metrics.shortcutSize,
            height: Metrics.shortcutSize
        )
        let candidateX = shortcutLabel.frame.maxX + Metrics.contentSpacing
        candidateLabel.frame = NSRect(
            x: candidateX,
            y: 0,
            width: max(bounds.width - candidateX - Metrics.horizontalInset, 0),
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
            backgroundColor = theme.selectedBackgroundColor
        } else if isPressed {
            backgroundColor = theme.pressedFillColor
        } else if isHovered {
            backgroundColor = theme.hoverFillColor
        } else {
            backgroundColor = .clear
        }

        shortcutLabel.textColor = isCandidateSelected
            ? NSColor.white.withAlphaComponent(0.92)
            : theme.shortcutTextColor
        shortcutLabel.layer?.backgroundColor = isCandidateSelected
            ? NSColor.white.withAlphaComponent(0.22).cgColor
            : theme.subtleFillColor.cgColor
        candidateLabel.textColor = isCandidateSelected
            ? .white
            : theme.primaryTextColor
        layer?.backgroundColor = backgroundColor.cgColor
    }
}

@MainActor
private final class ReverseLookupView: NSView {
    private enum Metrics {
        static let horizontalInset: CGFloat = 8
        static let characterWidth: CGFloat = 78
        static let itemHeight: CGFloat = 36
        static let contentSpacing: CGFloat = 6
        static let keycapSize: CGFloat = 28
        static let keycapSpacing: CGFloat = 6
        static let navigationButtonWidth: CGFloat = 32
        static let minimumPageLabelWidth: CGFloat = 33
        static let navigationHeight: CGFloat = 32
    }

    private let characterView: ReverseLookupCharacterView
    private let noCodeLabel: CandidateTextField
    private let previousCodeButton: CandidatePageButton
    private let pageLabel: CandidateTextField
    private let nextCodeButton: CandidatePageButton
    private var keycapViews: [ReverseLookupKeycapView] = []
    private var pageLabelLayoutWidth = Metrics.minimumPageLabelWidth
    private var theme: CandidateBarTheme = .current

    var onPageChanged: ((Int) -> Void)?

    override init(frame frameRect: NSRect) {
        characterView = ReverseLookupCharacterView(frame: .zero)
        noCodeLabel = CandidateTextField(labelWithString: "無拆碼")
        previousCodeButton = CandidatePageButton(
            symbolName: "chevron.left",
            accessibilityLabel: "上一組拆碼"
        )
        pageLabel = CandidateTextField(labelWithString: "")
        nextCodeButton = CandidatePageButton(
            symbolName: "chevron.right",
            accessibilityLabel: "下一組拆碼"
        )
        super.init(frame: frameRect)

        noCodeLabel.cell = VerticallyCenteredTextFieldCell(
            textCell: noCodeLabel.stringValue
        )
        noCodeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        noCodeLabel.textColor = theme.mutedTextColor
        noCodeLabel.lineBreakMode = .byClipping

        pageLabel.alignment = .center
        pageLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        pageLabel.textColor = theme.secondaryTextColor
        pageLabel.lineBreakMode = .byClipping
        pageLabel.setAccessibilityLabel("拆碼分頁")

        previousCodeButton.toolTip = "上一組拆碼"
        nextCodeButton.toolTip = "下一組拆碼"
        previousCodeButton.onPress = { [weak self] in
            self?.onPageChanged?(-1)
        }
        nextCodeButton.onPress = { [weak self] in
            self?.onPageChanged?(1)
        }

        addSubview(characterView)
        addSubview(noCodeLabel)
        addSubview(pageLabel)
        addSubview(previousCodeButton)
        addSubview(nextCodeButton)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("字根反查")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        character: String,
        code: String?,
        currentPage: Int,
        totalPages: Int
    ) {
        characterView.configure(character: character)

        for keycapView in keycapViews {
            keycapView.removeFromSuperview()
        }
        keycapViews = code?.map {
            let keycapView = ReverseLookupKeycapView(character: String($0), theme: theme)
            addSubview(keycapView)
            return keycapView
        } ?? []

        noCodeLabel.isHidden = code != nil
        pageLabel.stringValue = totalPages > 0
            ? "\(currentPage)/\(totalPages)"
            : "—"
        let maximumPageText = totalPages > 0
            ? "\(totalPages)/\(totalPages)"
            : "—"
        let pageTextWidth = ceil(
            (maximumPageText as NSString).size(
                withAttributes: [.font: pageLabel.font!]
            ).width
        )
        pageLabelLayoutWidth = max(
            Metrics.minimumPageLabelWidth,
            pageTextWidth + 8
        )
        pageLabel.setAccessibilityValue(
            totalPages > 0
                ? "第 \(currentPage) 組，共 \(totalPages) 組"
                : "沒有拆碼"
        )
        previousCodeButton.isEnabled = totalPages > 1
        nextCodeButton.isEnabled = totalPages > 1
        setAccessibilityValue(
            code.map {
                "\(character)，拆碼 \($0)，第 \(currentPage) 組，共 \(totalPages) 組"
            }
                ?? "\(character)，沒有拆碼"
        )
        needsLayout = true
    }

    func apply(theme: CandidateBarTheme) {
        self.theme = theme
        noCodeLabel.textColor = theme.mutedTextColor
        pageLabel.textColor = theme.secondaryTextColor
        characterView.apply(theme: theme)
        previousCodeButton.apply(theme: theme)
        nextCodeButton.apply(theme: theme)
        keycapViews.forEach { $0.apply(theme: theme) }
    }

    override func layout() {
        super.layout()

        let itemY = (bounds.height - Metrics.itemHeight) / 2
        characterView.frame = NSRect(
            x: Metrics.horizontalInset,
            y: itemY,
            width: Metrics.characterWidth,
            height: Metrics.itemHeight
        )

        let navigationWidth = Metrics.navigationButtonWidth * 2
            + pageLabelLayoutWidth
        let navigationX = bounds.maxX
            - Metrics.horizontalInset
            - navigationWidth
        let codeX = characterView.frame.maxX + Metrics.contentSpacing
        let availableCodeWidth = max(
            navigationX - Metrics.contentSpacing - codeX,
            0
        )

        if keycapViews.isEmpty {
            noCodeLabel.frame = NSRect(
                x: codeX,
                y: itemY,
                width: availableCodeWidth,
                height: Metrics.itemHeight
            )
        } else {
            let spacingWidth = Metrics.keycapSpacing
                * CGFloat(max(keycapViews.count - 1, 0))
            let keycapWidth = min(
                Metrics.keycapSize,
                max(
                    18,
                    (availableCodeWidth - spacingWidth) / CGFloat(keycapViews.count)
                )
            )
            var keycapX = codeX
            for keycapView in keycapViews {
                keycapView.frame = NSRect(
                    x: keycapX,
                    y: (bounds.height - Metrics.keycapSize) / 2,
                    width: keycapWidth,
                    height: Metrics.keycapSize
                )
                keycapX += keycapWidth + Metrics.keycapSpacing
            }
        }

        let pageLabelHeight = ceil(pageLabel.intrinsicContentSize.height)
        pageLabel.frame = NSRect(
            x: navigationX,
            y: (bounds.height - pageLabelHeight) / 2,
            width: pageLabelLayoutWidth,
            height: pageLabelHeight
        )
        let navigationY = (bounds.height - Metrics.navigationHeight) / 2
        previousCodeButton.frame = NSRect(
            x: pageLabel.frame.maxX,
            y: navigationY,
            width: Metrics.navigationButtonWidth,
            height: Metrics.navigationHeight
        )
        nextCodeButton.frame = NSRect(
            x: previousCodeButton.frame.maxX,
            y: navigationY,
            width: Metrics.navigationButtonWidth,
            height: Metrics.navigationHeight
        )
    }
}

@MainActor
private final class ReverseLookupCharacterView: NSView {
    private enum Metrics {
        static let horizontalInset: CGFloat = 14
        static let badgeSize: CGFloat = 18
        static let contentSpacing: CGFloat = 7
    }

    private let titleLabel: CandidateTextField
    private let characterLabel: CandidateTextField
    private var theme: CandidateBarTheme = .current

    override init(frame frameRect: NSRect) {
        titleLabel = CandidateTextField(labelWithString: "字")
        characterLabel = CandidateTextField(labelWithString: "")
        super.init(frame: frameRect)

        titleLabel.cell = VerticallyCenteredTextFieldCell(
            textCell: titleLabel.stringValue
        )
        characterLabel.cell = VerticallyCenteredTextFieldCell(
            textCell: characterLabel.stringValue
        )

        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous

        titleLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.92)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byClipping
        titleLabel.wantsLayer = true
        titleLabel.layer?.backgroundColor = NSColor.white.withAlphaComponent(
            0.22
        ).cgColor
        titleLabel.layer?.cornerRadius = Metrics.badgeSize / 2
        titleLabel.layer?.cornerCurve = .continuous
        titleLabel.layer?.masksToBounds = true

        characterLabel.font = .systemFont(ofSize: 21, weight: .medium)
        characterLabel.textColor = .white
        characterLabel.alignment = .center
        characterLabel.lineBreakMode = .byTruncatingTail
        characterLabel.maximumNumberOfLines = 1

        addSubview(titleLabel)
        addSubview(characterLabel)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        apply(theme: theme)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(character: String) {
        characterLabel.stringValue = character
        setAccessibilityLabel("反查字：\(character)")
        setAccessibilityValue(character)
    }

    func apply(theme: CandidateBarTheme) {
        self.theme = theme
        layer?.backgroundColor = theme.selectedBackgroundColor.cgColor
    }

    override func layout() {
        super.layout()

        titleLabel.frame = NSRect(
            x: Metrics.horizontalInset,
            y: (bounds.height - Metrics.badgeSize) / 2,
            width: Metrics.badgeSize,
            height: Metrics.badgeSize
        )
        let characterX = titleLabel.frame.maxX + Metrics.contentSpacing
        characterLabel.frame = NSRect(
            x: characterX,
            y: 0,
            width: max(bounds.width - characterX - Metrics.horizontalInset, 0),
            height: bounds.height
        )
    }
}

@MainActor
private final class ReverseLookupKeycapView: NSView {
    private let characterLabel: CandidateTextField
    private var theme: CandidateBarTheme

    init(character: String, theme: CandidateBarTheme) {
        self.theme = theme
        characterLabel = CandidateTextField(labelWithString: character)
        super.init(frame: .zero)

        characterLabel.cell = VerticallyCenteredTextFieldCell(
            textCell: characterLabel.stringValue
        )
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true

        characterLabel.alignment = .center
        characterLabel.font = .monospacedSystemFont(ofSize: 16, weight: .medium)
        addSubview(characterLabel)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("字根：\(character)")
        setAccessibilityValue(character)
        apply(theme: theme)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        characterLabel.frame = bounds
    }

    func apply(theme: CandidateBarTheme) {
        self.theme = theme
        layer?.backgroundColor = theme.subtleFillColor.cgColor
        characterLabel.textColor = theme.keycapTextColor
    }
}

@MainActor
private final class CandidatePageButton: NSControl {
    private let imageView: CandidateImageView
    private var trackingAreaReference: NSTrackingArea?
    private var isHovered = false
    private var isPressed = false
    private var theme: CandidateBarTheme = .current
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

    func apply(theme: CandidateBarTheme) {
        self.theme = theme
        updateAppearance()
    }

    private func updateAppearance() {
        let backgroundColor: NSColor
        if !isEnabled {
            backgroundColor = .clear
        } else if isPressed {
            backgroundColor = theme.pressedFillColor
        } else if isHovered {
            backgroundColor = theme.hoverFillColor
        } else {
            backgroundColor = .clear
        }

        imageView.contentTintColor = isEnabled
            ? theme.navigationIconColor
            : theme.navigationIconColor.withAlphaComponent(0.42)
        layer?.backgroundColor = backgroundColor.cgColor
    }
}
