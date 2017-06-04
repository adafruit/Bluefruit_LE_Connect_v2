//
//  UIImage+Tint.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

extension UIImage {
    func tintWithColor(_ color: UIColor) -> UIImage {

        UIGraphicsBeginImageContextWithOptions(self.size, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return self }

        // flip the image
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: 0.0, y: -self.size.height)

        // multiply blend mode
        context.setBlendMode(CGBlendMode.multiply)

        let rect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
        context.clip(to: rect, mask: self.cgImage!)
        color.setFill()
        context.fill(rect)

        // create uiimage
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage ?? self

    }
}
