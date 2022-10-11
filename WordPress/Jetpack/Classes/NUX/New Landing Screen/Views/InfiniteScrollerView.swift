import UIKit

/// A scroll view that produces an infinite scrolling effect.
///
/// Set the `scrollerDelegate` property to externally alter the scrolling rate speed and direction.
///
/// By default user interaction with the scroll view is disabled, but it can be enabled if desired.
///
/// Currently the view only supports vertical scrolling, but could easily be updated to support horizontal.
/// This class also currently makes the assumption that the view generated by the `viewBuilder` closure will be taller
/// than its frame.
class InfiniteScrollerView: UIScrollView {
    /// Delegate to poll for the speed and direction of the scrolling offset. Polled at the default rate of `CADisplayLink`.
    weak var scrollerDelegate: InfiniteScrollerViewDelegate?

    private var displayLink: CADisplayLink?

    /// Closure used to repeat a view to populate a `UIStackView` for scrolling.
    private var viewBuilder: (() -> UIView)?
    private var stackView: UIStackView?

    /// Returns the height of the first view in the stack view, if one exists. Used to compute reset points for vertical scrolling.
    private var singleViewHeight: CGFloat? {
        guard
            let stackView = stackView,
            !stackView.arrangedSubviews.isEmpty
        else {
            return nil
        }

        return stackView.arrangedSubviews[0].frame.size.height
    }

    override init(frame: CGRect) {
        guard viewBuilder != nil else {
            fatalError("this class must be initialized using init(frame:viewBuilder:)")
        }

        super.init(frame: frame)
    }

    /// Initializes a view that produces an infinite scrolling effect.
    /// - Parameter viewBuilder: Closure that generates a `UIView`. Repeatedly called to fill a `UIStackView` that will be scrolled.
    init(frame: CGRect = .zero, _ viewBuilder: @escaping (() -> UIView)) {
        super.init(frame: frame)
        self.viewBuilder = viewBuilder
        displayLink = CADisplayLink(target: self, selector: #selector(step))

        setupScrollView()
        let stackView = setupStackView()
        addSubview(stackView)

        pinSubviewToAllEdges(stackView)
        stackView.widthAnchor.constraint(equalTo: widthAnchor).isActive = true

        self.stackView = stackView
        addViewsToStackView()

        displayLink?.add(to: .current, forMode: .default)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addViewsToStackView() {
        guard
            let viewBuilder = viewBuilder,
            let stackView = stackView
        else {
            return
        }

        /// Note: This class makes the assumption that the view generated by `viewBuilder()` is taller than
        /// the scroll view's frame. To support views shorter than the frame it'd need to calculate how many times
        /// to repeat it based on the built view's height.
        for _ in 0...2 {
            stackView.addArrangedSubview(viewBuilder())
        }
    }

    private func setupScrollView() {
        delegate = self
        bounces = false
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        isUserInteractionEnabled = false
    }

    private func setupStackView() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }

    /// Called on each `CADisplayLink` frame and sets the vertical content offset if a scroller delegate is set.
    @objc private func step(displayLink: CADisplayLink) {
        let deviceFps = 1 / (displayLink.targetTimestamp - displayLink.timestamp)

        guard
            deviceFps > 0,
            let scrollerDelegate = self.scrollerDelegate,
            let singleViewHeight = self.singleViewHeight
        else {
            return
        }

        let rate = scrollerDelegate.rate(for: self)

        // the rate shouldn't be higher than the size of the view
        guard abs(rate) < singleViewHeight else {
            return
        }

        contentOffset.y += rate / deviceFps
    }
}

extension InfiniteScrollerView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let singleViewHeight = self.singleViewHeight else {
            return
        }

        let yOffset = contentOffset.y

        if yOffset >= singleViewHeight * 2 {
            contentOffset.y -= singleViewHeight
        } else if yOffset <= 0 {
            contentOffset.y += singleViewHeight
        }
    }
}
