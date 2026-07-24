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

#if canImport(UIKit) && os(iOS)
import UIKit

final class PWCarouselInAppView: UIView, PWInAppRenderable,
                                 UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    var onClose: (() -> Void)?
    var onAction: ((PWInAppAction) -> Void)?

    private let content: PWInAppCarouselContent
    private let backdrop = PWInAppStyle.makeBackdrop()
    private var card: UIView!
    private let pageControl = UIPageControl()
    private var collectionView: UICollectionView!

    init(content: PWInAppCarouselContent) {
        self.content = content
        super.init(frame: .zero)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Non-blocking like a banner: touches outside the card pass through to the
    // host app; only the card is interactive.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }

    private func buildUI() {
        backdrop.translatesAutoresizingMaskIntoConstraints = false
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

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: trailingAnchor),

            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            card.heightAnchor.constraint(equalTo: card.widthAnchor, multiplier: 1.32),

            collectionView.topAnchor.constraint(equalTo: card.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            pageControl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            pageControl.centerXAnchor.constraint(equalTo: card.centerXAnchor),
        ])

        // A carousel has no guaranteed way out on its own: slide taps fire an
        // optional action, there is no drag-to-dismiss and no auto-dismiss. Always
        // show the close chip so a campaign can't ship a trapped, unclosable card.
        let hasGuaranteedDismissPath = false
        if content.showCloseButton || !hasGuaranteedDismissPath {
            let close = PWInAppStyle.makeCloseButton()
            contentHost.addSubview(close)
            close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
            NSLayoutConstraint.activate([
                close.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
                close.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            ])
        }
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
        let width = scrollView.bounds.width
        guard width > 0 else { return }
        pageControl.currentPage = Int((scrollView.contentOffset.x + width / 2) / width)
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
