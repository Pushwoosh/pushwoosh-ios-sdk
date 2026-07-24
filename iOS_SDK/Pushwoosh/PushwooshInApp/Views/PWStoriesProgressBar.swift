//
//  PWStoriesProgressBar.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Segmented progress bar — one track per story page, the active one fills as
//  the page plays. Visual mirrors PushwooshNotificationUI's StoryProgressBarView.
//

#if canImport(UIKit) && os(iOS)
import UIKit

final class PWStoriesProgressBar: UIView {

    private let stack = UIStackView()
    private var trackViews: [UIView] = []
    private var fillWidthConstraints: [NSLayoutConstraint] = []

    private let trackColor = UIColor.white.withAlphaComponent(0.3)
    private let fillColor = UIColor.white

    private var activeIndex = 0
    private var activeProgress: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func configure(segmentCount: Int) {
        stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        trackViews = []
        fillWidthConstraints = []

        for _ in 0..<max(0, segmentCount) {
            let track = UIView()
            track.backgroundColor = trackColor
            track.layer.cornerRadius = 1.5
            track.clipsToBounds = true
            track.heightAnchor.constraint(equalToConstant: 3).isActive = true

            let fill = UIView()
            fill.backgroundColor = fillColor
            fill.translatesAutoresizingMaskIntoConstraints = false
            track.addSubview(fill)

            let widthConstraint = fill.widthAnchor.constraint(equalToConstant: 0)
            NSLayoutConstraint.activate([
                fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
                fill.topAnchor.constraint(equalTo: track.topAnchor),
                fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
                widthConstraint
            ])

            stack.addArrangedSubview(track)
            trackViews.append(track)
            fillWidthConstraints.append(widthConstraint)
        }
    }

    func update(activeIndex: Int, progress: CGFloat) {
        self.activeIndex = activeIndex
        self.activeProgress = min(max(progress, 0), 1)
        applyFills()
    }

    /// Recomputes absolute fill widths from the stored index/progress. Also runs
    /// on every layout pass, so fills stay correct after rotation / resize — the
    /// constraint constants are point widths, not relative to the track.
    private func applyFills() {
        let count = trackViews.count
        guard count > 0 else { return }
        // Derive each track's width from our own bounds (fillEqually) rather than
        // reading track.bounds, which isn't laid out yet when this runs from
        // layoutSubviews — so fills stay correct on the first pass and on rotation.
        let trackWidth = max(0, (bounds.width - stack.spacing * CGFloat(count - 1)) / CGFloat(count))
        for index in 0..<count {
            let fraction: CGFloat
            if index < activeIndex {
                fraction = 1
            } else if index == activeIndex {
                fraction = activeProgress
            } else {
                fraction = 0
            }
            fillWidthConstraints[index].constant = trackWidth * fraction
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyFills()
    }

    func reset() {
        activeIndex = 0
        activeProgress = 0
        fillWidthConstraints.forEach { $0.constant = 0 }
        UIView.performWithoutAnimation { layoutIfNeeded() }
    }
}
#endif
