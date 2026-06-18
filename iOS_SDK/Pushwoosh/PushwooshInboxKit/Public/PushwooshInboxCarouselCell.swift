//
//  PushwooshInboxCarouselCell.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 16.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Liquid Glass base + floating islands: the whole card is a frosted glass surface, and the
//  swipeable gallery, the title/body block and the page dots sit on top of it as separate,
//  inset "islands" so the glass shows around them. The text block collapses away when the
//  message carries no title/body (pure gallery on glass).
//

#if canImport(UIKit) && !os(watchOS)
import UIKit
import PushwooshCore

@objc(PushwooshInboxCarouselCell)
open class PushwooshInboxCarouselCell: PushwooshInboxCell {

    /// Invoked when a slide is tapped, carrying the slide's optional `url`. The
    /// controller opens the URL (and marks read) when present, otherwise falls through
    /// to the message's default row action.
    public var onCarouselSlideTap: ((URL?) -> Void)?

    private static let galleryHeight: CGFloat = 190

    // Serial so the shared CIContext inside pw_averageColor is never rendered on two threads at once.
    private static let accentColorQueue = DispatchQueue(label: "com.pushwoosh.inboxkit.accent-color")
    private let card = UIView()
    private let backdropImageView = UIImageView()
    private var backdropBlur: UIVisualEffectView?
    private var glassPlate: UIVisualEffectView?
    private var glassDotsView: UIView?
    private let pageControl = UIPageControl()
    private let pinChip = UIView()
    private let bodyStack = UIStackView()
    private let titleRow = UIView()
    private var textGlass: UIVisualEffectView?

    private let layout = PWCarouselFlowLayout()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.isPagingEnabled = true
        cv.showsHorizontalScrollIndicator = false
        cv.backgroundColor = .secondarySystemFill
        cv.contentInsetAdjustmentBehavior = .never
        cv.dataSource = self
        cv.delegate = self
        cv.register(PushwooshInboxCarouselSlideCell.self,
                    forCellWithReuseIdentifier: PushwooshInboxCarouselSlideCell.reuseID)
        return cv
    }()

    private var slides: [PushwooshInboxCarouselSlide] = []
    private var placeholder: UIImage?
    private var bodyTopConstraint: NSLayoutConstraint?
    private var bodyBottomConstraint: NSLayoutConstraint?

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        installCarouselLayout()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        installCarouselLayout()
    }

    private func installCarouselLayout() {
        resetInheritedLayout()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.masksToBounds = true
        contentView.addSubview(card)

        // Glass base behind the islands: a blurred slide photo + frosted blur + Liquid Glass, so the
        // surface reads as real frosted glass over imagery rather than a flat colour (filled in apply()).
        backdropImageView.translatesAutoresizingMaskIntoConstraints = false
        backdropImageView.contentMode = .scaleAspectFill
        backdropImageView.clipsToBounds = true
        backdropImageView.layer.cornerRadius = 24
        backdropImageView.layer.cornerCurve = .continuous
        backdropImageView.isHidden = true
        // The backdrop image must never drive the cell's height — its intrinsic size would otherwise
        // fight the island chain and stretch the self-sizing row (e.g. after returning from background).
        backdropImageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        backdropImageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        card.addSubview(backdropImageView)
        NSLayoutConstraint.activate([
            backdropImageView.topAnchor.constraint(equalTo: card.topAnchor),
            backdropImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            backdropImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            backdropImageView.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])

        if #available(iOS 26.0, *) {
            let blurV = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
            blurV.translatesAutoresizingMaskIntoConstraints = false
            blurV.isUserInteractionEnabled = false
            blurV.clipsToBounds = true
            blurV.layer.cornerRadius = 24
            blurV.layer.cornerCurve = .continuous
            blurV.isHidden = true
            card.addSubview(blurV)

            let plate = UIVisualEffectView(effect: pwInboxGlassEffect())
            plate.translatesAutoresizingMaskIntoConstraints = false
            plate.isUserInteractionEnabled = false
            plate.clipsToBounds = true
            plate.layer.cornerRadius = 24
            plate.layer.cornerCurve = .continuous
            plate.isHidden = true
            card.addSubview(plate)

            NSLayoutConstraint.activate([
                blurV.topAnchor.constraint(equalTo: card.topAnchor),
                blurV.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                blurV.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                blurV.bottomAnchor.constraint(equalTo: card.bottomAnchor),
                plate.topAnchor.constraint(equalTo: card.topAnchor),
                plate.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                plate.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                plate.bottomAnchor.constraint(equalTo: card.bottomAnchor)
            ])
            backdropBlur = blurV
            glassPlate = plate
        }

        // Gallery is a raised "island" on the glass base — rounded on all sides and inset from
        // the card edges so the frosted glass shows around it.
        collectionView.layer.cornerRadius = 16
        collectionView.layer.cornerCurve = .continuous
        collectionView.clipsToBounds = true
        card.addSubview(collectionView)

        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.hidesForSinglePage = true
        pageControl.currentPageIndicatorTintColor = .white
        pageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.45)
        pageControl.addTarget(self, action: #selector(pageControlChanged), for: .valueChanged)

        if #available(iOS 26.0, *) {
            // Each page dot is its own Liquid Glass drop — it shimmers with device motion and
            // refracts the slide photo behind it; the active dot stretches into a glass pill.
            let dots = GlassPageDots()
            dots.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(dots)
            glassDotsView = dots
            NSLayoutConstraint.activate([
                dots.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
                dots.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: -12)
            ])
        } else {
            if #available(iOS 14.0, *) { pageControl.backgroundStyle = .minimal }
            card.addSubview(pageControl)
            NSLayoutConstraint.activate([
                pageControl.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
                pageControl.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: -8)
            ])
        }

        pinChip.translatesAutoresizingMaskIntoConstraints = false
        pinChip.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        pinChip.layer.cornerRadius = 15
        pinChip.layer.cornerCurve = .continuous
        pinChip.isHidden = true
        card.addSubview(pinChip)

        pinIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        pinIndicatorView.contentMode = .scaleAspectFit
        pinIndicatorView.tintColor = .white
        pinChip.addSubview(pinIndicatorView)

        bodyStack.translatesAutoresizingMaskIntoConstraints = false
        bodyStack.axis = .vertical
        bodyStack.alignment = .fill
        bodyStack.distribution = .fill
        bodyStack.spacing = 4
        if #available(iOS 26.0, *) {
            // Frosted glass plate behind the title/body — its own island on the card.
            let plate = UIVisualEffectView(effect: pwInboxGlassEffect())
            plate.translatesAutoresizingMaskIntoConstraints = false
            plate.isUserInteractionEnabled = false
            plate.clipsToBounds = true
            plate.layer.cornerRadius = 16
            plate.layer.cornerCurve = .continuous
            plate.alpha = 0.45
            card.addSubview(plate)
            textGlass = plate
        }
        card.addSubview(bodyStack)

        titleRow.translatesAutoresizingMaskIntoConstraints = false
        bodyStack.addArrangedSubview(titleRow)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 1
        titleRow.addSubview(titleLabel)

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.textAlignment = .right
        dateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleRow.addSubview(dateLabel)

        // Unread dot — sits in the gutter to the left of the body block, vertically
        // centred on the title (hidden = invisible, layout unchanged).
        unreadIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        unreadIndicatorView.layer.cornerRadius = 4
        card.addSubview(unreadIndicatorView)

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.numberOfLines = 2
        bodyStack.addArrangedSubview(bodyLabel)

        let bodyTop = bodyStack.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 14)
        let bodyBottom = bodyStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        bodyTopConstraint = bodyTop
        bodyBottomConstraint = bodyBottom

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            collectionView.topAnchor.constraint(equalTo: card.topAnchor, constant: 5.5),
            collectionView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 5.5),
            collectionView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -5.5),
            {
                let c = collectionView.heightAnchor.constraint(equalToConstant: Self.galleryHeight)
                c.priority = .required - 1   // yield to UIView-Encapsulated-Layout-Height (self-sizing)
                return c
            }(),

            pinChip.topAnchor.constraint(equalTo: collectionView.topAnchor, constant: 14),
            pinChip.trailingAnchor.constraint(equalTo: collectionView.trailingAnchor, constant: -14),
            pinChip.widthAnchor.constraint(equalToConstant: 30),
            pinChip.heightAnchor.constraint(equalToConstant: 30),

            pinIndicatorView.centerXAnchor.constraint(equalTo: pinChip.centerXAnchor),
            pinIndicatorView.centerYAnchor.constraint(equalTo: pinChip.centerYAnchor),
            pinIndicatorView.widthAnchor.constraint(equalToConstant: 14),
            pinIndicatorView.heightAnchor.constraint(equalToConstant: 14),

            bodyTop,
            bodyStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 32),
            bodyStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            bodyBottom,

            unreadIndicatorView.trailingAnchor.constraint(equalTo: bodyStack.leadingAnchor, constant: -8),
            unreadIndicatorView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            unreadIndicatorView.widthAnchor.constraint(equalToConstant: 8),
            unreadIndicatorView.heightAnchor.constraint(equalToConstant: 8),

            titleLabel.leadingAnchor.constraint(equalTo: titleRow.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: titleRow.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: titleRow.bottomAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: dateLabel.leadingAnchor, constant: -8),

            dateLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: titleRow.trailingAnchor)
        ])

        if let textGlass = textGlass {
            // Centred on the card (symmetric 16pt insets), not hugging the asymmetric bodyStack —
            // bodyStack is offset right by the unread-dot gutter, which pushed the plate off-centre.
            NSLayoutConstraint.activate([
                textGlass.topAnchor.constraint(equalTo: bodyStack.topAnchor, constant: -10),
                textGlass.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 5.5),
                textGlass.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -5.5),
                textGlass.bottomAnchor.constraint(equalTo: bodyStack.bottomAnchor, constant: 10)
            ])
        }
    }

    open override func apply(message: PWInboxMessageProtocol, attributes: PushwooshInboxKitAttributes) {
        let style = attributes.style
        placeholder = style.imagePlaceholder

        card.layer.cornerRadius = 24
        card.layer.cornerCurve = .continuous
        slides = PushwooshInboxCarouselSlide.decode(from: message)
        collectionView.reloadData()
        collectionView.setContentOffset(.zero, animated: false)
        pageControl.numberOfPages = slides.count
        pageControl.currentPage = 0
        if #available(iOS 26.0, *) {
            (glassDotsView as? GlassPageDots)?.numberOfPages = slides.count
            (glassDotsView as? GlassPageDots)?.currentPage = 0
        }

        // Glass base: blurred first-slide photo behind frosted glass, so the surface reads as real
        // frosted glass over imagery instead of a flat colour. Falls back to a solid card.
        if style.isLiquidGlass, #available(iOS 26.0, *), let firstImage = slides.first?.imageUrl {
            card.backgroundColor = .clear
            backdropImageView.isHidden = false
            backdropBlur?.isHidden = false
            glassPlate?.isHidden = false
            MessageImageLoader.shared.load(firstImage, into: backdropImageView, placeholder: nil)
            // #6 adaptive tint: derive the image's average colour and let the page dots echo it.
            MessageImageLoader.shared.loadImage(firstImage) { [weak self] image in
                // Guard against a recycled cell: if this completion outlives the message it was
                // started for, the cell now shows a different slide — don't stamp a stale tint.
                guard let self = self, self.slides.first?.imageUrl == firstImage, let image = image else { return }
                // pw_averageColor runs a CIContext render — keep it off the main thread (serialized
                // so the shared context isn't hit concurrently), then hop back to apply the tint
                // (re-checking the cell wasn't recycled in the meantime).
                PushwooshInboxCarouselCell.accentColorQueue.async {
                    let color = image.pw_averageColor
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, self.slides.first?.imageUrl == firstImage else { return }
                        if #available(iOS 26.0, *) {
                            (self.glassDotsView as? GlassPageDots)?.accentColor = color
                        }
                    }
                }
            }
        } else {
            card.backgroundColor = style.backgroundColor
            backdropImageView.isHidden = true
            backdropBlur?.isHidden = true
            glassPlate?.isHidden = true
            backdropImageView.image = nil
        }

        titleLabel.text = message.title
        titleLabel.font = style.titleFont
        titleLabel.textColor = message.isRead ? style.titleColorRead : style.titleColorUnread

        bodyLabel.text = message.message
        bodyLabel.font = style.bodyFont
        bodyLabel.textColor = message.isRead ? style.bodyColorRead : style.bodyColorUnread

        dateLabel.text = style.dateFormatter(message.sendDate ?? Date())
        dateLabel.font = style.dateFont
        dateLabel.textColor = style.dateColor

        unreadIndicatorView.backgroundColor = style.unreadBadgeColor

        let isPinned = attributes.pinningEnabled && PushwooshInboxKitAttributes.isPinned(message)
        pinChip.isHidden = !isPinned || !attributes.pinIndicatorVisible
        if isPinned && attributes.pinIndicatorVisible {
            if let custom = style.pinIndicatorImage {
                pinIndicatorView.image = custom
            } else {                let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
                pinIndicatorView.image = UIImage(systemName: "pin.fill", withConfiguration: cfg)
            }
        }

        // Collapse the text block to a pure gallery when the message has no title/body.
        let hasTitle = !(message.title?.isEmpty ?? true)
        let hasBody = !(message.message?.isEmpty ?? true)
        let hasText = hasTitle || hasBody
        titleRow.isHidden = !hasTitle
        bodyLabel.isHidden = !hasBody
        bodyStack.isHidden = !hasText
        textGlass?.isHidden = !hasText
        bodyTopConstraint?.constant = hasText ? 14 : 0
        bodyBottomConstraint?.constant = hasText ? -18 : 0
        unreadIndicatorView.isHidden = message.isRead || !hasText
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        pinChip.isHidden = true
        unreadIndicatorView.isHidden = true
        slides = []
        collectionView.reloadData()
        card.layer.removeAllAnimations()
        card.transform = .identity
        MessageImageLoader.shared.cancelLoad(for: backdropImageView)
        backdropImageView.image = nil
        textGlass?.isHidden = true
        backdropBlur?.isHidden = true
        glassPlate?.isHidden = true
        if #available(iOS 26.0, *) {
            // Snap the dots back to page 0 here (cell is off-screen) so a recycled cell doesn't
            // animate the active drop sliding from the previous page when it next appears.
            (glassDotsView as? GlassPageDots)?.currentPage = 0
            (glassDotsView as? GlassPageDots)?.accentColor = nil
        }
    }

    /// Subtle press feedback for taps that land on the card chrome (text block, margins).
    open override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        setCardPressed(highlighted)
    }

    private func setCardPressed(_ pressed: Bool) {
        UIView.animate(withDuration: pressed ? 0.12 : 0.28, delay: 0,
                       usingSpringWithDamping: 0.9, initialSpringVelocity: 0,
                       options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.card.transform = pressed ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
        }
    }

    /// A quick press-and-release bounce, used for taps on a gallery slide (the collection view
    /// swallows the touch, so the table-cell highlight never fires there).
    fileprivate func bounceCard() {
        UIView.animate(withDuration: 0.1, delay: 0,
                       options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.card.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        } completion: { _ in
            UIView.animate(withDuration: 0.28, delay: 0,
                           usingSpringWithDamping: 0.85, initialSpringVelocity: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.card.transform = .identity
            }
        }
    }

    @objc private func pageControlChanged() {
        let page = pageControl.currentPage
        let offset = CGPoint(x: CGFloat(page) * collectionView.bounds.width, y: 0)
        collectionView.setContentOffset(offset, animated: true)
    }
}

// MARK: - Slide gallery data source / delegate

extension PushwooshInboxCarouselCell: UICollectionViewDataSource, UICollectionViewDelegate {

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        slides.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PushwooshInboxCarouselSlideCell.reuseID, for: indexPath)
        if let slideCell = cell as? PushwooshInboxCarouselSlideCell, indexPath.item < slides.count {
            slideCell.configure(with: slides[indexPath.item], placeholder: placeholder)
        }
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < slides.count else { return }
        bounceCard()
        onCarouselSlideTap?(slides[indexPath.item].url)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let width = scrollView.bounds.width
        guard width > 0 else { return }
        // Clamp: rubber-band overscroll past the first/last slide can push the rounded page out of
        // 0..<count, which would leave GlassPageDots with no active drop (all dimmed).
        let raw = Int((scrollView.contentOffset.x / width).rounded())
        let page = max(0, min(raw, slides.count - 1))
        pageControl.currentPage = page
        if #available(iOS 26.0, *) {
            (glassDotsView as? GlassPageDots)?.currentPage = page
        }
    }
}

// MARK: - Slide gallery layout

/// Flow layout for the slide gallery: each page fills the collection's current bounds, and the
/// layout re-flows whenever those bounds change. This is what makes a carousel inserted into an
/// already-visible inbox render correctly — the cell starts at width 0 (its `apply()` reload runs
/// before the table sizes the row) and only gets its real width on the next layout pass. The stock
/// `UICollectionViewFlowLayout` does not re-flow on that 0→width change, so the slides would stay
/// at their width-0 size until a full reload (e.g. closing and reopening the inbox).
private final class PWCarouselFlowLayout: UICollectionViewFlowLayout {
    override init() {
        super.init()
        scrollDirection = .horizontal
        minimumLineSpacing = 0
        minimumInteritemSpacing = 0
        sectionInset = .zero
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func prepare() {
        super.prepare()
        guard let collectionView = collectionView else { return }
        if collectionView.bounds.width > 0, itemSize != collectionView.bounds.size {
            itemSize = collectionView.bounds.size
        }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        collectionView?.bounds.size != newBounds.size
    }
}

// MARK: - Single slide cell

final class PushwooshInboxCarouselSlideCell: UICollectionViewCell {

    static let reuseID = "pw.inbox.carousel.slide"

    let imageView = UIImageView()
    private let scrim = CarouselGradientView()
    private let captionLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)

        scrim.translatesAutoresizingMaskIntoConstraints = false
        scrim.isHidden = true
        contentView.addSubview(scrim)

        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        captionLabel.numberOfLines = 2
        captionLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        captionLabel.textColor = .white
        captionLabel.layer.shadowColor = UIColor.black.cgColor
        captionLabel.layer.shadowOpacity = 0.35
        captionLabel.layer.shadowRadius = 3
        captionLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        captionLabel.isHidden = true
        contentView.addSubview(captionLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            scrim.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrim.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            scrim.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.55),

            captionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            captionLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -18),
            captionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -22)
        ])
    }

    func configure(with slide: PushwooshInboxCarouselSlide, placeholder: UIImage?) {
        MessageImageLoader.shared.load(slide.imageUrl, into: imageView, placeholder: placeholder)
        // Image-only slides are tappable — give VoiceOver/automation a labelled button element.
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = slide.title ?? "Slide"
        if let caption = slide.title {
            captionLabel.text = caption
            captionLabel.isHidden = false
            scrim.isHidden = false
        } else {
            captionLabel.text = nil
            captionLabel.isHidden = true
            scrim.isHidden = true
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        MessageImageLoader.shared.cancelLoad(for: imageView)
        imageView.image = nil
        captionLabel.text = nil
        captionLabel.isHidden = true
        scrim.isHidden = true
    }
}

/// A view whose backing layer is a vertical clear→dark gradient, so it resizes with Auto Layout
/// without manual frame math.
final class CarouselGradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        guard let gradient = layer as? CAGradientLayer else { return }
        gradient.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.55).cgColor]
        gradient.locations = [0.0, 1.0]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1.0)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

// MARK: - Glass page dots

/// Custom page indicator where every dot is its own Liquid Glass drop (iOS 26+): each shimmers with
/// device motion and refracts the content behind it, and the active dot stretches into a glass pill.
@available(iOS 26.0, *)
final class GlassPageDots: UIView {

    private let container: UIVisualEffectView
    private let stack = UIStackView()
    private var dots: [UIVisualEffectView] = []
    private var widthConstraints: [NSLayoutConstraint] = []
    private let dotSize: CGFloat = 8
    private let activeWidth: CGFloat = 22

    var numberOfPages: Int = 0 {
        didSet { if numberOfPages != oldValue { rebuild() } }
    }

    var currentPage: Int = 0 {
        didSet { if currentPage != oldValue { updateActive(animated: true) } }
    }

    /// Accent colour for the active drop — set to the slide image's average colour so the dots
    /// echo the photo's palette.
    var accentColor: UIColor? {
        didSet { updateActive(animated: false) }
    }

    override init(frame: CGRect) {
        // spacing 12 = distance at which neighbouring glass drops begin to merge — the active pill
        // stretches toward its neighbours and they fuse like liquid.
        container = UIVisualEffectView(effect: pwInboxGlassContainerEffect(spacing: 12))
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        container = UIVisualEffectView(effect: pwInboxGlassContainerEffect(spacing: 12))
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isUserInteractionEnabled = false
        addSubview(container)
        // Decorative dots aren't interactive, but expose the current page to VoiceOver.
        isAccessibilityElement = true
        accessibilityLabel = "Page"
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false
        container.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.contentView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: container.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.contentView.trailingAnchor)
        ])
    }

    private func rebuild() {
        dots.forEach { $0.removeFromSuperview() }
        dots.removeAll()
        widthConstraints.removeAll()
        guard numberOfPages > 1 else { return }
        for _ in 0..<numberOfPages {
            let dot = UIVisualEffectView(effect: pwInboxGlassEffect())
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.clipsToBounds = true
            dot.layer.cornerRadius = dotSize / 2
            dot.layer.cornerCurve = .continuous
            let width = dot.widthAnchor.constraint(equalToConstant: dotSize)
            NSLayoutConstraint.activate([width, dot.heightAnchor.constraint(equalToConstant: dotSize)])
            widthConstraints.append(width)
            stack.addArrangedSubview(dot)
            dots.append(dot)
        }
        updateActive(animated: false)
    }

    private func updateActive(animated: Bool) {
        accessibilityValue = numberOfPages > 0 ? "\(currentPage + 1) of \(numberOfPages)" : nil
        guard !dots.isEmpty else { return }
        let changes = {
            for (index, dot) in self.dots.enumerated() {
                let isActive = (index == self.currentPage)
                self.widthConstraints[index].constant = isActive ? self.activeWidth : self.dotSize
                dot.alpha = isActive ? 1.0 : 0.5
                dot.contentView.backgroundColor = isActive ? self.accentColor?.withAlphaComponent(0.55) : nil
            }
            self.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85,
                           initialSpringVelocity: 0, options: [.allowUserInteraction], animations: changes)
        } else {
            changes()
        }
    }
}
#endif
