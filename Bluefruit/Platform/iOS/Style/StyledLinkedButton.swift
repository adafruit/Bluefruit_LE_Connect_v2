//
//  StyledLinkedButton.swift
//  Bluefruit Calibration
//
//  Created by Antonio García on 22/02/16.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import UIKit

@IBDesignable
class StyledLinkedButton: IntrinsicSizeWithInsetsButton {

//    static let kTouchAlphaEnabled: CGFloat = 1.0
//    static let kTouchAlphaDisabled: CGFloat = 0.3

    @IBInspectable var useStyleOnTouch = true {
        didSet {
            adjustsImageWhenHighlighted = !useStyleOnTouch
//            alpha = useStyleOnTouch ? StyledLinkedButton.kTouchAlphaDisabled:StyledLinkedButton.kTouchAlphaEnabled
        }
    }

    /*@IBInspectable */var linkedView: UIView?

    var onTouchUpInside: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        useStyleOnTouch = true
        linkedView = self       // Start with itself as linked view
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

 /*
        if useStyleOnTouch {
            alpha = StyledLinkedButton.kTouchAlphaEnabled
        }
   */
        if let linkedView = linkedView {
            StyledAnimations.animationTouchDown(view: linkedView)
        }

    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
/*
        if useStyleOnTouch {
            alpha = StyledLinkedButton.kTouchAlphaDisabled
        }
 */
        if let linkedView = linkedView {
            StyledAnimations.animationTouchUp(view: linkedView)
            onTouchUpInside?()
        }

    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
/*
        if useStyleOnTouch {
            alpha = StyledLinkedButton.kTouchAlphaDisabled
        }
  */      
        if let linkedView = linkedView {
            StyledAnimations.animationTouchUp(view: linkedView)
        }
    }

}
