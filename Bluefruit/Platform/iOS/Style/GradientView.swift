//
//  GradientView.swift
//  Bluefruit
//
//  Created by Antonio on 02/02/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class GradientView: UIView {

    var endColor: UIColor {
        didSet {
            self.setNeedsDisplay()
        }
    }

    required init(coder aDecoder: NSCoder) {
        endColor = UIColor.white
        super.init(coder: aDecoder)!
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Create a gradient from white to red
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        endColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let colors: [CGFloat] = [ 0, 0, 0, 1, red, green, blue, alpha]

        let baseSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorSpace: baseSpace, colorComponents: colors, locations: nil, count: 2)

        context.saveGState()

        let startPoint = CGPoint(x: rect.minX, y: rect.midY)
        let endPoint = CGPoint(x: rect.maxX, y: rect.midY)

        context.drawLinearGradient(gradient!, start: startPoint, end: endPoint, options: CGGradientDrawingOptions.drawsBeforeStartLocation)
        context.restoreGState()
    }
}
