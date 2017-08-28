//
//  ThermalCameraModuleManager.swift
//  Bluefruit
//
//  Created by Antonio García on 27/08/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit


protocol ThermalCameraModuleManagerDelegate: class {
    func onThermalUartIsReady(error: Error?)
    func onImageUpdated(_ image: UIImage)
}

class ThermalCameraModuleManager: NSObject {
    // Config
    private static let kColdHue: Double = 270       // Hue for coldest color
    private static let kHotHue: Double = 0          // Hue for hottest color
    
    
    // Params
    var isColorEnabled = true
    weak var delegate: ThermalCameraModuleManagerDelegate?
    
    // Data
    fileprivate var blePeripheral: BlePeripheral
    fileprivate let uartManager: UartDataManager// = UartDataManager(delegate: self)
    
    fileprivate var textCachedBuffer: String = ""
    fileprivate var textCachedBufferLock = NSLock()
    
    fileprivate var minTemperature = Double.greatestFiniteMagnitude
    fileprivate var maxTemperature = -Double.greatestFiniteMagnitude
    

    // MARK: -
    init(blePeripheral: BlePeripheral, delegate: ThermalCameraModuleManagerDelegate) {
        self.blePeripheral = blePeripheral
        self.delegate = delegate
        uartManager = UartDataManager(delegate: nil)
        super.init()
        
        uartManager.delegate = self
    }
    
    deinit {
        DLog("thermalcamera deinit")
    }
    
    public var lowerTemperature: Double {
        return minTemperature
    }

    public var upperTemperature: Double {
        return maxTemperature
    }
    
    public var isTemperatureReadReceived: Bool {
        return minTemperature < Double.greatestFiniteMagnitude && maxTemperature > -Double.greatestFiniteMagnitude
    }

    
    // MARK: - Start / Stop
    func start() {
        DLog("thermalcamera start")
        
        // Enable Uart
        blePeripheral.uartEnable(uartRxHandler: uartManager.rxDataReceived) { [weak self] error in
            self?.delegate?.onThermalUartIsReady(error: error)
        }
    }
    
    func stop() {
        DLog("thermalcamera stop")
        
        blePeripheral.reset()
    }
    
    func isReady() -> Bool {
        return blePeripheral.isUartEnabled()
    }
    
    // MARK: - Uart Data Cache
    fileprivate func uartTextBuffer() -> String {
        return textCachedBuffer
    }

    func uartRxCacheReset() {
        uartManager.clearRxCache(peripheralIdentifier: blePeripheral.identifier)
        textCachedBuffer.removeAll()
    }
    
    // MARK: - Process
    fileprivate func processBuffer(adding dataString: String) {
        textCachedBufferLock.lock(); defer { textCachedBufferLock.unlock() }
        
        textCachedBuffer.append(dataString)
        
        var finished = false
        repeat {
            
            let startRange = textCachedBuffer.range(of: "[")
            let endRange = textCachedBuffer.range(of: "]")
            
            if let startRange = startRange, let endRange = endRange {
                var imageComponentsString = textCachedBuffer.substring(with: startRange.upperBound..<endRange.lowerBound)
                imageComponentsString = imageComponentsString.components(separatedBy: .whitespacesAndNewlines).joined() // Remove spaces and newlines: https://stackoverflow.com/questions/28570973/how-should-i-remove-all-the-spaces-from-a-string-swift/39067610#39067610
                imageComponentsString = imageComponentsString.trimmingCharacters(in: CharacterSet(charactersIn: ","))       // Trim extra commas
                
                let imageComponents = imageComponentsString.components(separatedBy: ",")
                
                let imageValues = imageComponents.map({Double($0) ?? 0})
                
                // Update max and min
                imageValues.forEach({
                    if $0 > maxTemperature {
                        maxTemperature = $0
                    }
                    else if $0 < minTemperature {
                        minTemperature = $0
                    }
                })
                
                // Create updated image
                createImage(values: imageValues)
                
                // Remove processed text
                textCachedBuffer.removeSubrange(textCachedBuffer.startIndex...endRange.lowerBound)
            }
            else  if let endRange = endRange, startRange == nil || endRange.lowerBound < startRange!.lowerBound {
                // Remove orphaned text
                textCachedBuffer.removeSubrange(textCachedBuffer.startIndex...endRange.lowerBound)
            }
            else {
                finished = true
            }
        }while(!finished)
    }
    
    private func createImage(values: [Double]) {
        
        let temperatureRange = maxTemperature - minTemperature
        let valuesNormalized: [Double] = values.map({
            (($0 - minTemperature) / temperatureRange)
        })
        
        let pixelData: [PixelData] = valuesNormalized.map({
            
            let colorComponents = temperatureComponentsForValue($0)
            return pixelDataFromRgb(r: colorComponents.r, g: colorComponents.g, b: colorComponents.b)
        })

        let dimen = Int(floor(sqrt(Double(pixelData.count))))
        if let image = imageFromARGB32Bitmap(pixels: pixelData, width: dimen, height: dimen) {
            DispatchQueue.main.async { [unowned self] in
                self.delegate?.onImageUpdated(image)
            }
        }
    }
    
    // MARK: - Create Image
    private struct PixelData {
        var a: UInt8 = 255
        var r: UInt8
        var g: UInt8
        var b: UInt8
    }
    private let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    private let bitmapInfo:CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
    
    
    private func imageFromARGB32Bitmap(pixels: [PixelData], width: Int, height: Int) -> UIImage? {
        // Based on http://blog.human-friendly.com/drawing-images-from-pixel-data-in-swift
        guard pixels.count == width * height else { DLog("Invalid pixel count"); return nil }
        
        let bitsPerComponent = 8
        let bitsPerPixel = 32

        var data = pixels // Copy to mutable []
        guard let providerRef = CGDataProvider(data: NSData(bytes: &data, length: data.count * MemoryLayout<PixelData>.size)) else { return nil }
        
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: width * MemoryLayout<PixelData>.size,
            space: rgbColorSpace,
            bitmapInfo: bitmapInfo,
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
            ) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    
    // MARK: - Color
    public func temperatureComponentsForValue(_ value: Double) -> (r: Double, g: Double, b: Double) {
        if isColorEnabled {
            return temperatureColorComponentsForValue(value)
        }
        else {
            return (value, value, value)
        }
    }
    
    private func temperatureColorComponentsForValue(_ value: Double) -> (r: Double, g: Double, b: Double) {
        let hue = ThermalCameraModuleManager.kColdHue + (ThermalCameraModuleManager.kHotHue-ThermalCameraModuleManager.kColdHue) * value
        let colorComponents = rgb(h: hue, s: 0.7, v: 0.5)
        return colorComponents
    }
    
    private func rgb(h: Double, s: Double, v: Double) -> (r: Double, g: Double, b: Double) {
        // Based on: https://gist.github.com/FredrikSjoberg/cdea97af68c6bdb0a89e3aba57a966ce
        
        if s == 0 { return (r: v, g: v, b: v) } // Achromatic grey
        
        let angle = (h >= 360 ? 0 : h)
        let sector = angle / 60 // Sector
        let i = floor(sector)
        let f = sector - i // Factorial part of h
        
        let p = v * (1 - s)
        let q = v * (1 - (s * f))
        let t = v * (1 - (s * (1 - f)))
        
        switch(i) {
        case 0:
            return (r: v, g: t, b: p)
        case 1:
            return (r: q, g: v, b: p)
        case 2:
            return (r: p, g: v, b: t)
        case 3:
            return (r: p, g: q, b: v)
        case 4:
            return (r: t, g: p, b: v)
        default:
            return (r: v, g: p, b: q)
        }
    }
    
    private func pixelDataFromRgb(r: Double, g: Double, b: Double) -> PixelData {
        return PixelData(a: 255, r: UInt8(r * 255), g: UInt8(g * 255), b: UInt8(b * 255))
    }

}


// MARK: - UartDataManagerDelegate
extension ThermalCameraModuleManager: UartDataManagerDelegate {
    func onUartRx(data: Data, peripheralIdentifier: UUID) {
        if let dataString = stringFromData(data, useHexMode: false) {
            // DLog("rx: \(dataString)")
            
            processBuffer(adding: dataString)
        }
        uartManager.removeRxCacheFirst(n: data.count, peripheralIdentifier: peripheralIdentifier)
    }
}
