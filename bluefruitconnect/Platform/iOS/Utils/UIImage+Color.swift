//
//  UIImage+Color.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 16/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation


extension UIImage
{
    // from: http://stackoverflow.com/questions/26542035/create-uiimage-with-solid-color-in-swift
    convenience init(color: UIColor, size: CGSize = CGSizeMake(1, 1)) {
        let rect = CGRectMake(0, 0, size.width, size.height)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.init(CGImage: image.CGImage!)
    }
}