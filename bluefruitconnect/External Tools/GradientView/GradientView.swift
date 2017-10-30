//
//  GradientView.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 6/29/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import UIKit

class GradientView: UIView {
    
    var endColor:UIColor {
        didSet{
            self.setNeedsDisplay()
        }
    }
    
//    func setEndColor(newColor:UIColor){
//        
//        endColor = newColor
//        
//        self.setNeedsDisplay()
//    }
    required init(coder aDecoder: NSCoder) {
        endColor = UIColor.white
        super.init(coder: aDecoder)!
    }
    
  override func draw(_ rect: CGRect) {
        
        // Create a gradient from white to red
        var red:CGFloat = 0.0
        var green:CGFloat = 0.0
        var blue:CGFloat = 0.0
        var alpha:CGFloat = 0.0
        endColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let colors:[CGFloat] = [
            0.0, 0.0, 0.0, 1.0,
            red, green, blue, alpha]
        
        let baseSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorSpace: baseSpace, colorComponents: colors, locations: nil, count: 2)
//        CGColorSpaceRelease(baseSpace)
//        baseSpace = nil
        
        let context = UIGraphicsGetCurrentContext()
        
        context!.saveGState()
//        CGContextClip(context) 
    
        let startPoint = CGPoint(x: rect.minX, y: rect.minY)
        let endPoint = CGPoint(x: rect.maxX, y: rect.maxY)
        
        context!.drawLinearGradient(gradient!, start: startPoint, end: endPoint, options: CGGradientDrawingOptions.drawsBeforeStartLocation)
//        CGGradientRelease(gradient), gradient = NULL
        
        context!.restoreGState()
        
        //    CGContextDrawPath(context, kCGPathStroke);
    }
    

}
