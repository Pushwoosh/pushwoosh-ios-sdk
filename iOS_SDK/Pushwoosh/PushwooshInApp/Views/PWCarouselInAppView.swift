//
//  PWCarouselInAppView.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Swipeable carousel card: a paged collection of image slides with a gradient
//  scrim, rounded-face title overlay and a pill page control. Tapping a slide
//  fires its URL action. Neither Braze nor CleverTap ship a native carousel.
//
//  Blocking, like Android's carousel: an 80%-black scrim covers the host screen
//  and a tap on it dismisses the card — the second way out besides the ✕.
//

#if canImport(UIKit) && os(iOS)
import UIKit

final class PWCarouselInAppView: UIView, PWInAppRenderable,
                                 UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    private enum Metrics {
        static let sideInset: CGFloat = 22
        static let aspect: CGFloat = 1.32
        static let maxCardWidth: CGFloat = 480
    }

    var onClose: (() -> Void)?
    var onAction: ((PWInAppAction) -> Void)?

    private let content: PWInAppCarouselContent
    private let backdrop = PWInAppStyle.makeBackdrop(dimmed: true)
    private var card: UIView!
    private let pageControl = UIPageControl()
    private var collectionView: UICollectionView!
    private var currentPage = 0
    private var pagedWidth: CGFloat = 0

    init(content: PWInAppCarouselContent) {
        self.content = content
        super.init(frame: .zero)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        // The scrim is the only dismiss path besides the ✕, so it takes the tap
        // itself rather than relying on the root: the card sits above it and
        // swallows its own touches, so a tap here is always an outside tap.
        backdrop.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closeTapped)))
        addSubview(backdrop)

        let (surface, contentHost, _) = PWInAppStyle.makeSurface(
            glassTint: UIColor(white: 0.1, alpha: 0.35),
            solidColor: .black,
            cornerRadius: PWInAppStyle.cardCornerRadius)
        card = surface
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        collectionView.register(PWCarouselCell.self, forCellWithReuseIdentifier: PWCarouselCell.reuseId)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(collectionView)

        pageControl.numberOfPages = content.items.count
        pageControl.currentPage = 0
        pageControl.hidesForSinglePage = true
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.currentPageIndicatorTintColor = .white
        pageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.4)
        contentHost.addSubview(pageControl)

        // Height is what runs out in landscape: at width × 1.32 a full-width card
        // is taller than the screen, and the ✕, the dots and the slide caption —
        // all pinned to the card's edges — end up off it. So the width is only a
        // preference: the safe-area height cap wins and the card narrows, keeping
        // its ratio. Same rule as Android's carouselCardSize.
        let preferredWidth = card.widthAnchor.constraint(equalTo: safeAreaLayoutGuide.widthAnchor,
                                                        constant: -2 * Metrics.sideInset)
        preferredWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: trailingAnchor),

            card.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
            preferredWidth,
            // The sheet and the modal cap their width; the carousel did not, so on an
            // iPad it stretched to nearly the full screen — a card meant to be held
            // in one hand. Same cap as the sheet's.
            card.widthAnchor.constraint(lessThanOrEqualToConstant: Metrics.maxCardWidth),
            card.heightAnchor.constraint(equalTo: card.widthAnchor, multiplier: Metrics.aspect),
            card.heightAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.heightAnchor,
                                        constant: -2 * Metrics.sideInset),

            collectionView.topAnchor.constraint(equalTo: card.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            pageControl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            pageControl.centerXAnchor.constraint(equalTo: card.centerXAnchor),
        ])

        // The close chip ignores `showClose` and is always shown (Android forces
        // it too): the scrim tap aside, a carousel has no way out of its own —
        // slide taps fire an optional action, there is no drag-to-dismiss and no
        // auto-dismiss — and a scrim tap is not something a user can guess.
        let close = PWInAppStyle.makeCloseButton()
        contentHost.addSubview(close)
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            close.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
        ])
    }

    @objc private func closeTapped() {
        onClose?()
    }

    // MARK: - UICollectionView

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return content.items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PWCarouselCell.reuseId, for: indexPath)
        (cell as? PWCarouselCell)?.configure(with: content.items[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let action = content.items[indexPath.item].action {
            onAction?(action)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        pageControl.currentPage = page(in: scrollView)
    }

    // The settled page, not the one under the finger: it is what a bounds change
    // re-pins to, and mid-scroll (or mid-rotation) readings would move that target.
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        currentPage = page(in: scrollView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            currentPage = page(in: scrollView)
        }
    }

    // Clamped: a rubber-band offset past either end would otherwise name a page
    // that doesn't exist, and layoutSubviews re-pins to whatever this returns.
    private func page(in scrollView: UIScrollView) -> Int {
        let width = scrollView.bounds.width
        guard width > 0 else { return currentPage }
        let raw = Int((scrollView.contentOffset.x + width / 2) / width)
        return min(max(raw, 0), max(content.items.count - 1, 0))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Paging offsets are in points, so the card narrowing on rotation leaves
        // the collection view parked between two slides. Re-pin it to the page the
        // user is on — Android's ViewPager2 keeps its page across the same
        // configuration change on its own.
        let width = collectionView.bounds.width
        guard width > 0, width != pagedWidth else {
            return
        }
        pagedWidth = width
        collectionView.setContentOffset(CGPoint(x: CGFloat(currentPage) * width, y: 0), animated: false)
    }

    // MARK: - PWInAppRenderable

    func present(in container: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: container.topAnchor),
            bottomAnchor.constraint(equalTo: container.bottomAnchor),
            leadingAnchor.constraint(equalTo: container.leadingAnchor),
            trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        container.layoutIfNeeded()
        PWInAppStyle.animateIn(card: card, backdrop: backdrop)
    }

    func dismiss(completion: @escaping () -> Void) {
        PWInAppStyle.animateOut(card: card, backdrop: backdrop) {
            self.removeFromSuperview()
            completion()
        }
    }
}

/// One carousel slide: full-bleed image with a gradient scrim and rounded-face
/// title at the bottom.
final class PWCarouselCell: UICollectionViewCell {

    static let reuseId = "PWCarouselCell"

    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let textStack = UIStackView()
    private let scrim = PWGradientScrimView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        scrim.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrim)

        titleLabel.font = PWInAppStyle.rounded(20, .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2

        subtitleLabel.font = PWInAppStyle.rounded(14, .regular)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        subtitleLabel.numberOfLines = 2

        textStack.axis = .vertical
        textStack.spacing = 3
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            scrim.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrim.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            scrim.heightAnchor.constraint(equalToConstant: 140),

            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -36),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        titleLabel.text = nil
        subtitleLabel.text = nil
    }

    func configure(with item: PWInAppCarouselItem) {
        titleLabel.text = item.title?.text
        titleLabel.textColor = item.title?.color ?? .white
        titleLabel.isHidden = (item.title?.text.isEmpty ?? true)
        subtitleLabel.text = item.subtitle?.text
        subtitleLabel.textColor = item.subtitle?.color ?? UIColor.white.withAlphaComponent(0.85)
        subtitleLabel.isHidden = (item.subtitle?.text.isEmpty ?? true)
        scrim.isHidden = ((item.title?.text.isEmpty ?? true) && (item.subtitle?.text.isEmpty ?? true))
        PWInAppImageLoader.shared.load(item.imageURL, into: imageView)
    }
}
#endif
