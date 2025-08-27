//
//  ForegroundPushShape.swift
//  PushwooshForegroundPush
//
//  Created by André Kis on 21.08.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import UIKit
import PushwooshBridge

@available(iOS 13.0, *)
class ForegroundPushShape {
    
    static var useLiquidView: Bool = false
    
    static func applyStyle(_ style: PWForegroundPushStyle, to view: UIView, gradientColors: [UIColor]? = nil, backgroundColor: UIColor? = nil, usePushAnimation: Bool, useLiquidView: Bool) {
        self.useLiquidView = useLiquidView
        applyBackground(to: view, gradientColors: gradientColors, backgroundColor: backgroundColor)

        switch style {
        case .style1:
            applyStyle1(to: view, usePushAnimation: usePushAnimation)
        @unknown default:
            break
        }
    }
    
    private static func applyBackground(
        to view: UIView,
        gradientColors: [UIColor]?,
        backgroundColor: UIColor?
    ) {
        view.layer.sublayers?.removeAll(where: { $0 is CAGradientLayer })
        
        if let userColors = gradientColors, !userColors.isEmpty {
            let gradient = CAGradientLayer()
            gradient.colors = userColors.map { $0.cgColor }
            gradient.startPoint = CGPoint(x: 0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 0.5)
            gradient.frame = view.bounds
            view.layer.insertSublayer(gradient, at: 0)
        } else if let bgColor = backgroundColor {
            view.backgroundColor = bgColor
        } else {
            if (!self.useLiquidView) {
                applyGradient(to: view)
            }
        }
    }
    
    private static func applyGradient(to view: UIView) {
        let gradient = CAGradientLayer()
        gradient.colors = [UIColor.systemBlue.cgColor, UIColor.systemGreen.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.frame = view.bounds
        view.layer.insertSublayer(gradient, at: 0)
    }
    
    private static func applyStyle1(to view: UIView, usePushAnimation: Bool) {
        if (self.useLiquidView) {
            createLiquidNotificationShapeWithEffectView(for: view, usePushAnimation: usePushAnimation)
        } else {
            createLiquidNotificationShape(for: view, usePushAnimation: usePushAnimation)
        }
    }
    
    private static func createLiquidNotificationShapeWithEffectView(for inputView: UIView, usePushAnimation: Bool) {
        let targetView: UIView
        if let effectView = inputView as? UIVisualEffectView {
            targetView = effectView.contentView
        } else {
            targetView = inputView
        }

        if !usePushAnimation {
            let cornerRadius: CGFloat = min(targetView.bounds.width, targetView.bounds.height) * 0.1
            targetView.layer.cornerRadius = cornerRadius
            targetView.layer.masksToBounds = true
            return
        }

        let w = targetView.bounds.width
        let h = targetView.bounds.height
        guard w > 0 && h > 0 else { return }

        let cornerRadius: CGFloat = min(w, h) * 0.15

        func wavePath(topOffset: CGFloat, rightOffset: CGFloat, bottomOffset: CGFloat, leftOffset: CGFloat) -> UIBezierPath {
            let path = UIBezierPath()
            
            path.move(to: CGPoint(x: cornerRadius, y: 0 + topOffset))
            path.addCurve(to: CGPoint(x: w - cornerRadius, y: 0 - topOffset),
                          controlPoint1: CGPoint(x: w * 0.25, y: 0 + topOffset * 1.5),
                          controlPoint2: CGPoint(x: w * 0.75, y: 0 - topOffset * 1.5))
            path.addQuadCurve(to: CGPoint(x: w, y: cornerRadius + rightOffset),
                              controlPoint: CGPoint(x: w, y: 0))

            path.addCurve(to: CGPoint(x: w, y: h - cornerRadius + rightOffset),
                          controlPoint1: CGPoint(x: w + rightOffset, y: h * 0.35),
                          controlPoint2: CGPoint(x: w - rightOffset, y: h * 0.65))
            path.addQuadCurve(to: CGPoint(x: w - cornerRadius, y: h + bottomOffset),
                              controlPoint: CGPoint(x: w, y: h))

            path.addCurve(to: CGPoint(x: cornerRadius, y: h - bottomOffset),
                          controlPoint1: CGPoint(x: w * 0.75, y: h + bottomOffset * 1.5),
                          controlPoint2: CGPoint(x: w * 0.25, y: h - bottomOffset * 1.5))
            path.addQuadCurve(to: CGPoint(x: 0, y: h - cornerRadius + leftOffset),
                              controlPoint: CGPoint(x: 0, y: h))

            path.addCurve(to: CGPoint(x: 0, y: cornerRadius - leftOffset),
                          controlPoint1: CGPoint(x: -leftOffset, y: h * 0.65),
                          controlPoint2: CGPoint(x: -leftOffset, y: h * 0.35))
            path.addQuadCurve(to: CGPoint(x: cornerRadius, y: 0 + topOffset),
                              controlPoint: CGPoint(x: 0, y: 0))

            path.close()
            return path
        }

        let mask = CAShapeLayer()
        mask.path = wavePath(topOffset: 0, rightOffset: 0, bottomOffset: 0, leftOffset: 0).cgPath
        targetView.layer.mask = mask

        let animation = CAKeyframeAnimation(keyPath: "path")
        animation.values = [
            wavePath(topOffset:  0, rightOffset:  0, bottomOffset:  0, leftOffset:  0).cgPath,
            wavePath(topOffset:  8, rightOffset: -6, bottomOffset:  5, leftOffset: -4).cgPath,
            wavePath(topOffset: -6, rightOffset:  8, bottomOffset: -8, leftOffset:  6).cgPath,
            wavePath(topOffset:  0, rightOffset:  0, bottomOffset:  0, leftOffset:  0).cgPath
        ]
        animation.duration = 3.5
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        mask.add(animation, forKey: "liquidWaveAnimation")
    }

    
    private static func createLiquidNotificationShape(for view: UIView, usePushAnimation: Bool) {
        if !usePushAnimation {
            let cornerRadius: CGFloat = min(view.bounds.width, view.bounds.height) * 0.1
            view.layer.cornerRadius = cornerRadius
            view.layer.masksToBounds = true
            return
        }

        let w = view.bounds.width
        let h = view.bounds.height
        guard w > 0 && h > 0 else { return }

        let cornerRadius: CGFloat = min(w, h) * 0.15

        func wavePath(topOffset: CGFloat, rightOffset: CGFloat, bottomOffset: CGFloat, leftOffset: CGFloat) -> UIBezierPath {
            let path = UIBezierPath()
            
            path.move(to: CGPoint(x: cornerRadius, y: 0 + topOffset))
            path.addCurve(to: CGPoint(x: w - cornerRadius, y: 0 - topOffset),
                          controlPoint1: CGPoint(x: w * 0.25, y: 0 + topOffset * 1.5),
                          controlPoint2: CGPoint(x: w * 0.75, y: 0 - topOffset * 1.5))
            path.addQuadCurve(to: CGPoint(x: w, y: cornerRadius + rightOffset),
                              controlPoint: CGPoint(x: w, y: 0))

            path.addCurve(to: CGPoint(x: w, y: h - cornerRadius + rightOffset),
                          controlPoint1: CGPoint(x: w + rightOffset, y: h * 0.35),
                          controlPoint2: CGPoint(x: w - rightOffset, y: h * 0.65))
            path.addQuadCurve(to: CGPoint(x: w - cornerRadius, y: h + bottomOffset),
                              controlPoint: CGPoint(x: w, y: h))

            path.addCurve(to: CGPoint(x: cornerRadius, y: h - bottomOffset),
                          controlPoint1: CGPoint(x: w * 0.75, y: h + bottomOffset * 1.5),
                          controlPoint2: CGPoint(x: w * 0.25, y: h - bottomOffset * 1.5))
            path.addQuadCurve(to: CGPoint(x: 0, y: h - cornerRadius + leftOffset),
                              controlPoint: CGPoint(x: 0, y: h))

            path.addCurve(to: CGPoint(x: 0, y: cornerRadius - leftOffset),
                          controlPoint1: CGPoint(x: -leftOffset, y: h * 0.65),
                          controlPoint2: CGPoint(x: -leftOffset, y: h * 0.35))
            path.addQuadCurve(to: CGPoint(x: cornerRadius, y: 0 + topOffset),
                              controlPoint: CGPoint(x: 0, y: 0))

            path.close()
            return path
        }

        let mask = CAShapeLayer()
        mask.path = wavePath(topOffset: 0, rightOffset: 0, bottomOffset: 0, leftOffset: 0).cgPath
        view.layer.mask = mask

        let animation = CAKeyframeAnimation(keyPath: "path")
        animation.values = [
            wavePath(topOffset:  0, rightOffset:  0, bottomOffset:  0, leftOffset:  0).cgPath,
            wavePath(topOffset:  8, rightOffset: -6, bottomOffset:  5, leftOffset: -4).cgPath,
            wavePath(topOffset: -6, rightOffset:  8, bottomOffset: -8, leftOffset:  6).cgPath,
            wavePath(topOffset:  0, rightOffset:  0, bottomOffset:  0, leftOffset:  0).cgPath
        ]
        animation.duration = 3.5
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        mask.add(animation, forKey: "liquidWaveAnimation")
    }

    private static func createWaveBlobShape(for view: UIView) {
        let w = view.bounds.width
        let h = view.bounds.height
        guard w > 0 && h > 0 else { return }

        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: h * 0.1))
        path.addCurve(to: CGPoint(x: w, y: h * 0.1),
                      controlPoint1: CGPoint(x: w * 0.3, y: -h * 0.05),
                      controlPoint2: CGPoint(x: w * 0.7, y: h * 0.05))
        path.addCurve(to: CGPoint(x: w, y: h * 0.9),
                      controlPoint1: CGPoint(x: w + w * 0.05, y: h * 0.3),
                      controlPoint2: CGPoint(x: w - w * 0.05, y: h * 0.7))
        path.addCurve(to: CGPoint(x: 0, y: h * 0.9),
                      controlPoint1: CGPoint(x: w * 0.7, y: h + h * 0.05),
                      controlPoint2: CGPoint(x: w * 0.3, y: h - h * 0.05))
        path.addCurve(to: CGPoint(x: 0, y: h * 0.1),
                      controlPoint1: CGPoint(x: -w * 0.05, y: h * 0.7),
                      controlPoint2: CGPoint(x: w * 0.05, y: h * 0.3))
        path.close()

        let mask = CAShapeLayer()
        mask.path = path.cgPath
        view.layer.mask = mask
    }
    
    private static func createTopWaveShape(for view: UIView) {
        let w = view.bounds.width
        let h = view.bounds.height
        let cornerRadius: CGFloat = 12
        guard w > 0 && h > 0 else { return }

        let path = UIBezierPath()
        
        path.move(to: CGPoint(x: 0, y: h * 0.2))
        path.addCurve(to: CGPoint(x: w, y: h * 0.2),
                      controlPoint1: CGPoint(x: w * 0.25, y: 0),
                      controlPoint2: CGPoint(x: w * 0.75, y: h * 0.4))
        
        path.addLine(to: CGPoint(x: w, y: h - cornerRadius))
        path.addQuadCurve(to: CGPoint(x: w - cornerRadius, y: h),
                          controlPoint: CGPoint(x: w, y: h))
        
        path.addLine(to: CGPoint(x: cornerRadius, y: h))
        path.addQuadCurve(to: CGPoint(x: 0, y: h - cornerRadius),
                          controlPoint: CGPoint(x: 0, y: h))
        
        path.addLine(to: CGPoint(x: 0, y: h * 0.2))
        path.close()

        let mask = CAShapeLayer()
        mask.path = path.cgPath
        view.layer.mask = mask
    }
    
    private static func createCustomBlobShape(for view: UIView) {
        let w = view.bounds.width
        let h = view.bounds.height
        guard w > 0 && h > 0 else { return }
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0.2, y: h * 0.45))
        
        path.addCurve(to: CGPoint(x: w * 0.28, y: 0.1),
                      controlPoint1: CGPoint(x: 0.05, y: 0),
                      controlPoint2: CGPoint(x: w * 0.15, y: 0.05))
        
        path.addCurve(to: CGPoint(x: w * 0.8, y: 0),
                      controlPoint1: CGPoint(x: w * 0.35, y: h * 0.1),
                      controlPoint2: CGPoint(x: w * 0.65, y: -h * 0.1))
        
        path.addCurve(to: CGPoint(x: w, y: h * 0.3),
                      controlPoint1: CGPoint(x: w * 0.9, y: 0.05),
                      controlPoint2: CGPoint(x: w, y: 0.1))
        
        path.addCurve(to: CGPoint(x: w, y: h * 0.8),
                      controlPoint1: CGPoint(x: w + w * 0.15, y: h * 0.5),
                      controlPoint2: CGPoint(x: w + w * 0.15, y: h * 0.5))
        
        path.addCurve(to: CGPoint(x: w * 0.85, y: h),
                      controlPoint1: CGPoint(x: w, y: h),
                      controlPoint2: CGPoint(x: w * 0.9, y: h))
        
        path.addCurve(to: CGPoint(x: w * 0.25, y: h),
                      controlPoint1: CGPoint(x: w * 0.65, y: h + h * 0.3),
                      controlPoint2: CGPoint(x: w * 0.46, y: h + h * 0.2))
        
        path.addCurve(to: CGPoint(x: 0, y: h * 0.8),
                      controlPoint1: CGPoint(x: w * 0.1, y: h),
                      controlPoint2: CGPoint(x: 0, y: h))
        
        path.close()
        
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        view.layer.mask = mask
    }


}
