//
//  PushwooshInlineSlot.swift
//  PushwooshInApp
//
//  Created by André Kis on 29.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import SwiftUI

/// SwiftUI inline banner slot, a wrapper over `PushwooshInlineView`. Zero height while the
/// slot has no banner; grows to the banner's height with an animation when one arrives, so a
/// `VStack`, `List` or `ScrollView` makes room for it.
///
/// ```swift
/// VStack {
///     DealsView()
///     PushwooshInlineSlot(slotId: "home_top")
///     RecentlyViewedView()
/// }
/// ```
public struct PushwooshInlineSlot: View {

    private let slotId: String
    @State private var height: CGFloat = 0

    public init(slotId: String) {
        self.slotId = slotId
    }

    public var body: some View {
        PWInlineSlotRepresentable(slotId: slotId, height: $height)
            .frame(height: height)
    }
}

private struct PWInlineSlotRepresentable: UIViewRepresentable {

    let slotId: String
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> PushwooshInlineView {
        PushwooshInlineView(slotId: slotId)
    }

    func updateUIView(_ view: PushwooshInlineView, context: Context) {
        view.slotId = slotId
        let height = $height
        view.onHeightChange = { newHeight in
            DispatchQueue.main.async {
                guard !UIAccessibility.isReduceMotionEnabled else {
                    height.wrappedValue = newHeight
                    return
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    height.wrappedValue = newHeight
                }
            }
        }
    }
}
#endif
