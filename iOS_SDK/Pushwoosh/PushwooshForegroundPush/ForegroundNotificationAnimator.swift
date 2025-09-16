//
//  ForegroundNotificationAnimator.swift
//  PushwooshForegroundPush
//
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import UIKit
import PushwooshBridge

@available(iOS 13.0, *)
class ForegroundNotificationAnimator {
    
    // MARK: - Show Animations
    
    static func animateShow(for view: UIView, completion: (() -> Void)? = nil) {
        view.transform = CGAffineTransform(translationX: 0, y: -100).rotated(by: -0.05)
        UIView.animate(withDuration: 0.5,
                       delay: 0,
                       usingSpringWithDamping: 0.6,
                       initialSpringVelocity: 1.2,
                       options: .curveEaseOut) {
            view.alpha = 1
            view.transform = .identity
        } completion: { _ in
            completion?()
        }
    }
    
    // MARK: - Disappear Animations
    
    static func animateDisappear(for view: UIView,
                                animation: PWForegroundPushDisappearedAnimation,
                                duration: Int) {
        switch animation {
        case .balls:
            animateBallsDisappear(for: view, duration: duration)
        case .regularPush:
            animateRegularPushDisappear(for: view, duration: TimeInterval(duration))
        @unknown default:
            animateRegularPushDisappear(for: view, duration: TimeInterval(duration))
        }
    }
    
    private static func animateRegularPushDisappear(for view: UIView, duration: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            UIView.animate(withDuration: 0.4,
                           delay: 0,
                           options: .curveEaseIn,
                           animations: {
                view.transform = CGAffineTransform(translationX: 0, y: -300)
                view.alpha = 0
            }) { _ in
                view.removeFromSuperview()
            }
        }
    }
    
    private static func animateBallsDisappear(for view: UIView, duration: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(duration)) {
            guard let superview = view.superview else { return }
            
            // Create snapshot
            guard let snapshotImage = createSnapshot(of: view) else {
                view.removeFromSuperview()
                return
            }
            
            // Create balls
            let balls = createBalls(from: snapshotImage, view: view, superview: superview)
            view.removeFromSuperview()
            
            // Animate balls
            animateBalls(balls)
        }
    }
    
    private static func createSnapshot(of view: UIView) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, UIScreen.main.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        view.layer.render(in: context)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    private static func createBalls(from image: UIImage,
                                   view: UIView,
                                   superview: UIView) -> [UIView] {
        let ballDiameter: CGFloat = 12
        let cols = Int(ceil(image.size.width / ballDiameter))
        let rows = Int(ceil(image.size.height / ballDiameter))
        
        var balls: [UIView] = []
        
        for row in 0..<rows {
            for col in 0..<cols {
                let x = CGFloat(col) * ballDiameter
                let y = CGFloat(row) * ballDiameter
                let rect = CGRect(x: x, y: y, width: ballDiameter, height: ballDiameter)
                
                guard let cgImage = image.cgImage?.cropping(to: rect) else { continue }
                
                let ball = UIImageView(image: UIImage(cgImage: cgImage))
                ball.frame = view.convert(rect, to: superview)
                ball.layer.cornerRadius = ballDiameter / 2
                ball.clipsToBounds = true
                superview.addSubview(ball)
                balls.append(ball)
            }
        }
        
        return balls
    }
    
    private static func animateBalls(_ balls: [UIView]) {
        for ball in balls {
            let dx = CGFloat.random(in: -150...150)
            let dy = CGFloat.random(in: -200...50)
            let rotation = CGFloat.random(in: -CGFloat.pi...CGFloat.pi)
            let duration = Double.random(in: 0.5...1.2)
            
            UIView.animate(withDuration: duration,
                          delay: 0,
                          options: .curveEaseOut,
                          animations: {
                ball.center = CGPoint(x: ball.center.x + dx, y: ball.center.y + dy)
                ball.transform = CGAffineTransform(rotationAngle: rotation).scaledBy(x: 0.1, y: 0.1)
                ball.alpha = 0
            }) { _ in
                ball.removeFromSuperview()
            }
        }
    }
}
