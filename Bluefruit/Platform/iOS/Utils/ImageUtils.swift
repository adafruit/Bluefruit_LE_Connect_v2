//
//  ImageUtils.swift
//  Bluefruit
//
//  Created by Antonio García on 10/01/2020.
//  Copyright © 2020 Adafruit. All rights reserved.
//

import Foundation

// Image transformation utils. Used on the ImageTransfer module
struct ImageUtils {
    
    #if targetEnvironment(macCatalyst)
    #else
    static func applyEInkModeToImage(_ image: UIImage) -> UIImage {
        MagickWandGenesis()
        defer { MagickWandTerminus() }

        // Load image
        guard let imageData = image.pngData() else { return image }
        let imageDataBytes = [UInt8](imageData)
        let imageWand = NewMagickWand()
        var status = MagickReadImageBlob(imageWand, imageDataBytes, imageData.count)
        guard status != MagickFalse else { return image }
        
        defer { DestroyMagickWand(imageWand) }

        // Load palette
        //let paletteImage = UIImage(named: "eink3color")!
        //guard let paletteImageData = paletteImage.pngData() else { return image }
        let url = Bundle.main.url(forResource: "eink3color", withExtension: "png")!
        let paletteImageData = try! Data(contentsOf: url)
        
        let paletteWand = NewMagickWand()
        let paletteImageDataBytes = [UInt8](paletteImageData)
        status = MagickReadImageBlob(paletteWand, paletteImageDataBytes, paletteImageData.count)
        guard status != MagickFalse else { return image }

        defer { DestroyMagickWand(paletteWand) }
        
        // Remap colors
        status = MagickRemapImage(imageWand, paletteWand, FloydSteinbergDitherMethod)
        guard status != MagickFalse else { return image }
        
        var resultBytesSize = 0
        guard let resultBytes = MagickGetImageBlob(imageWand, &resultBytesSize) else { return image }
        let data = Data(bytes: resultBytes, count: resultBytesSize)
        
        MagickRelinquishMemory(resultBytes)
        
        let resultImage = UIImage(data: data)
        return resultImage ?? image
    }
    #endif
    
    /**
     Convert RGB color to L*a*b scale
     /based on https://stackoverflow.com/questions/9018016/how-to-compare-two-colors-for-similarity-difference
     */
    /*
    private static func rgb2lab(r R: UInt8, g G: UInt8, b B: UInt8) -> (Int, Int, Int) {
        
        let eps = 216.0 / 24389.0
        let k = 24389.0 / 27.0
        
        let Xr = 0.964221  // reference white D50
        let Yr = 1.0
        let Zr = 0.825211
        
        // RGB to XYZ
        var r = Double(R) / 255.0; //R 0..1
        var g = Double(G) / 255.0; //G 0..1
        var b = Double(B) / 255.0; //B 0..1
        
        // assuming sRGB (D65)
        if r <= 0.04045 {
            r = r / 12.92
        }
        else {
            r = pow((r + 0.055) / 1.055, 2.4)
        }
        
        if g <= 0.04045 {
            g = g / 12.92
        }
        else {
            g = pow((g + 0.055) / 1.055, 2.4)
        }
        
        if b <= 0.04045 {
            b = b / 12.92
        }
        else {
            b = pow((b + 0.055) / 1.055, 2.4)
        }
        
        let X = 0.436052025 * r + 0.385081593 * g + 0.143087414 * b
        let Y = 0.222491598 * r + 0.71688606 * g + 0.060621486 * b
        let Z = 0.013929122 * r + 0.097097002 * g + 0.71418547 * b
        
        // XYZ to Lab
        let xr = X / Xr
        let yr = Y / Yr
        let zr = Z / Zr
        
        let fx: Double
        if xr > eps {
            fx = pow(xr, 1 / 3.0)
        }
        else {
            fx = (k * xr + 16.0) / 116.0
        }
        
        let fy: Double
        if yr > eps {
            fy = pow(yr, 1 / 3.0)
        }
        else {
            fy = (k * yr + 16.0) / 116.0
        }
        
        let fz: Double
        if zr > eps {
            fz = pow(zr, 1 / 3.0)
        }
        else {
            fz = (k * zr + 16.0) / 116
        }
        
        let Ls = (116 * fy) - 16
        let as_ = 500 * (fx - fy)
        let bs_ = 200 * (fy - fz)
        
        let labX = Int(2.55 * Ls + 0.5)
        let labY = Int(as_ + 0.5)
        let labZ = Int(bs_ + 0.5)
        return (labX, labY, labZ)
        
    }
 */
    
    /**
     * Computes the difference between two RGB colors by converting them to the L*a*b scale and
     * comparing them using the CIE76 algorithm { http://en.wikipedia.org/wiki/Color_difference#CIE76}
     */
    /*
    static func colorDifference(r1: UInt8, g1: UInt8, b1: UInt8, r2: UInt8, g2: UInt8, b2: UInt8) -> Double {
        let (lab1r, lab1g, lab1b) = rgb2lab(r: r1, g: g1, b: b1)
        let (lab2r, lab2g, lab2b) = rgb2lab(r: r2, g: g2, b: b2)
        return colorDifference(lab1r: lab1r, lab1g: lab1g, lab1b: lab1b, lab2r: lab2r, lab2g: lab2g, lab2b: lab2b)
    }
    
    static func colorDifference(lab1r: Int, lab1g: Int, lab1b: Int, lab2r: Int, lab2g: Int, lab2b: Int) -> Double {
        let diffR = Double(lab2r - lab1r)
        let diffG = Double(lab2g - lab1g)
        let diffB = Double(lab2b - lab1b)

        return sqrt(diffR*diffR + diffG*diffG + diffB*diffB)
    }
    
    static func colorDifferenceSquared(lab1r: Int, lab1g: Int, lab1b: Int, lab2r: Int, lab2g: Int, lab2b: Int) -> Double {
        let diffR = Double(lab2r - lab1r)
        let diffG = Double(lab2g - lab1g)
        let diffB = Double(lab2b - lab1b)

        return diffR*diffR + diffG*diffG + diffB*diffB
    }*/

    static func scaleAndRotateImage(image: UIImage, resolution: CGSize, rotationDegrees: CGFloat, backgroundColor: UIColor) -> UIImage? {
        
        // Calculate resolution for fitted image
        let widthRatio = resolution.width / image.size.width
        let heightRatio = resolution.height / image.size.height
        
        var fitResolution = resolution
        if heightRatio < widthRatio  {
            fitResolution.width = resolution.height / image.size.height * image.size.width
        }
        else if widthRatio < heightRatio  {
            fitResolution.height = resolution.width / image.size.width * image.size.height
        }
        
        guard let fitImage = imageRotatedByDegrees(image: image, scaledToSize: fitResolution, rotationDegrees: rotationDegrees) else { return nil }
        
        // Draw fitImage centered in canvas
        let x = ceil((resolution.width - fitImage.size.width) / 2)
        let y = ceil((resolution.height - fitImage.size.height) / 2)
        let fitDrawRect = CGRect(x: x, y: y, width: fitImage.size.width, height: fitImage.size.height)
        
        UIGraphicsBeginImageContext(resolution)
        if let context = UIGraphicsGetCurrentContext() {
            backgroundColor.setFill()
            context.fill(CGRect(x: 0, y: 0, width: resolution.width, height: resolution.height))
            
            // Draw fit image at center
            fitImage.draw(in: fitDrawRect)
        }
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    private static func imageRotatedByDegrees(image: UIImage, scaledToSize newSize: CGSize, rotationDegrees: CGFloat) -> UIImage? {
        // based on: https://stackoverflow.com/questions/40882487/how-to-rotate-image-in-swift
        // calculate the size of the rotated view's containing box for our drawing space
        let rotatedViewBox = UIView(frame: CGRect(x:0, y:0, width: newSize.width, height: newSize.height))
        let t = CGAffineTransform(rotationAngle: self.degreesToRadians(rotationDegrees))
        rotatedViewBox.transform = t
        let rotatedSize = rotatedViewBox.frame.size
        
        // Create the bitmap context
        UIGraphicsBeginImageContext(rotatedSize)
        if let context = UIGraphicsGetCurrentContext(), let cgImage = image.cgImage {
            // Move the origin to the middle of the image so we will rotate and scale around the center.
            context.translateBy(x: rotatedSize.width/2, y: rotatedSize.height/2)

            // Rotate the image context
            context.rotate(by:degreesToRadians(rotationDegrees))
            
            // Now, draw the rotated/scaled image into the context
            context.scaleBy(x: 1, y: -1)
            context.draw(cgImage, in: CGRect(x: -newSize.width / 2, y: -newSize.height / 2, width: newSize.width, height: newSize.height), byTiling: false)
        }
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    private static func degreesToRadians(_ degrees: CGFloat) -> CGFloat {
        return degrees * .pi / 180
    }
}
