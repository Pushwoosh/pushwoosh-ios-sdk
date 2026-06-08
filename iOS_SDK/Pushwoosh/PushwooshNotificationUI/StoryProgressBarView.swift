//
//  StoryProgressBarView.swift
//  PushwooshNotificationUI
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import UIKit

final class StoryProgressBarView: UIView {

    private let stack = UIStackView()
    private var trackViews: [UIView] = []
    private var fillWidthConstraints: [NSLayoutConstraint] = []

    private let trackColor = UIColor.white.withAlphaComponent(0.3)
    private let fillColor = UIColor.white

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
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
        for (index, track) in trackViews.enumerated() {
            let fraction: CGFloat
            if index < activeIndex {
                fraction = 1
            } else if index == activeIndex {
                fraction = min(max(progress, 0), 1)
            } else {
                fraction = 0
            }
            fillWidthConstraints[index].constant = track.bounds.width * fraction
        }
    }

    /// Instantly clears every segment and flushes layout outside any animation, so a later
    /// `layoutIfNeeded()` running inside an animation (e.g. the CTA cross-dissolve on a loop
    /// restart) doesn't pick up the reset and animate all bars rolling back at once.
    func reset() {
        fillWidthConstraints.forEach { $0.constant = 0 }
        UIView.performWithoutAnimation { layoutIfNeeded() }
    }
}
