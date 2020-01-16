//
//  GradientView.swift
//  Bluefruit
//
//  Created by Antonio on 02/02/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class ThermalGradientView: UIView {
    // Config
    private static let kNumColorSegments = 5        // Color gradient is more accurate with a bigger number of segments
    
    // Params
    var thermalCameraData: ThermalCameraModuleManager?
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }

    override func draw(_ rect: CGRect) {
        guard let thermalCameraData = thermalCameraData else { DLog("Error: no thermalCameraData"); return }
        guard let context = UIGraphicsGetCurrentContext() else { return }

        var colors = [CGFloat]()      // r, g, b, a
        var x: Double = 0
        repeat {
            let colorComponents = thermalCameraData.temperatureComponentsForValue(x)
            colors.append(contentsOf: [CGFloat(colorComponents.r), CGFloat(colorComponents.g), CGFloat(colorComponents.b), CGFloat(1)])
            
            x += 1.0/Double(ThermalGradientView.kNumColorSegments)
        } while (x<=1)
        
        let baseSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorSpace: baseSpace, colorComponents: colors, locations: nil, count: colors.count / 4)

        context.saveGState()

        let startPoint = CGPoint(x: rect.minX, y: rect.midY)
        let endPoint = CGPoint(x: rect.maxX, y: rect.midY)

        context.drawLinearGradient(gradient!, start: startPoint, end: endPoint, options: CGGradientDrawingOptions.drawsBeforeStartLocation)
        context.restoreGState()
    }
}
