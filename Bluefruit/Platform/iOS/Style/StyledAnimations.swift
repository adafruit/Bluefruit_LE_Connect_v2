//
//  StyledAnimations.swift
//  Bluefruit Calibration
//
//  Created by Antonio García on 21/02/16.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import UIKit

class StyledAnimations {

    static let kAnimationDownDuration = 0.15
    static let kAnimationUpDuration = 0.3
    static let kAnimationDownScale: CGFloat = 0.9

    static func animationTouchDown(view: UIView) {
        UIView.animate(withDuration: StyledAnimations.kAnimationDownDuration) { () -> Void in
            view.transform = CGAffineTransform(scaleX: StyledAnimations.kAnimationDownScale, y: StyledAnimations.kAnimationDownScale)
        }
    }

    static func animationTouchUp(view: UIView) {
        UIView.animate(withDuration: StyledAnimations.kAnimationUpDuration) { () -> Void in
            view.transform = .identity
        }
    }

    static func animationErrorShake(view: UIView) {
        // Animate
        let kStepDuration = 0.030
        UIView.animate(withDuration: kStepDuration, delay: 0, options: [.curveEaseIn], animations: {
            view.transform = CGAffineTransform(translationX: 20, y: 0)
        }) { (finished) -> Void in

            UIView.animate(withDuration: kStepDuration*2, delay: 0, options: [.curveLinear], animations: {
                view.transform = CGAffineTransform(translationX: -20, y: 0)
            }) { (finished) -> Void in

                UIView.animate(withDuration: kStepDuration, delay: 0, options: [.curveEaseOut], animations: {
                    view.transform = .identity
                }) { (finished) -> Void in

                }
            }
        }
    }
}
