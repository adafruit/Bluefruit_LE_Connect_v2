//
//  UIImage+pixelData.swift
//  Bluefruit
//
//  Created by Antonio García on 11/06/2019.
//  Copyright © 2019 Adafruit. All rights reserved.
//

import Foundation

// based on: https://stackoverflow.com/questions/33768066/get-pixel-data-as-array-from-uiimage-cgimage-in-swift
extension UIImage {
    func pixelData32bitRGB() -> [UInt8]? {
        let bitsPerComponent = 8
        let size = self.size
        let dataSize = Int(size.width) * Int(size.height) * 4
        var pixelData = [UInt8](repeating: 0, count: dataSize)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData,
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: 4 * Int(size.width),
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let cgImage = self.cgImage else { return nil }
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        return pixelData
    }
    
    convenience init?(pixels: [UInt8], width: Int, height: Int) {
        let bitsPerComponent = 8
        let bytesPerPixel = 3
        let bitsPerPixel = bytesPerPixel * bitsPerComponent
        let bytesPerRow = bytesPerPixel * width
        let totalBytes = height * bytesPerRow
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

        var pixelValues = pixels
        let bitmapInfo: CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        guard let providerRef = CGDataProvider(data: NSData(bytes: &pixelValues, length: totalBytes)) else { return nil }
        guard let cgImage = CGImage(width: width,
                                    height: height,
                                    bitsPerComponent: bitsPerComponent,
                                    bitsPerPixel: bitsPerPixel,
                                    bytesPerRow: bytesPerRow,
                                    space: rgbColorSpace,
                                    bitmapInfo: bitmapInfo,
                                    provider: providerRef, decode: nil,
                                    shouldInterpolate: false,
                                    intent: CGColorRenderingIntent.defaultIntent) else { return nil }
        
        self.init(cgImage: cgImage)
    }
}
