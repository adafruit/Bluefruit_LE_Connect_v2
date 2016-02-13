//
//  ControllerColorWheelViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class ControllerColorWheelViewController: UIViewController {

    //  Constants 
    static let prefix = "!C"

    // UI
//    @IBOutlet weak var wheelView: ISColorWheel!

    @IBOutlet weak var wheelContainerView: UIView!
    @IBOutlet weak var brightnessSlider: UISlider!
    @IBOutlet weak var colorView: UIView!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var sliderGradientView: GradientView!
    
    // Data
    private var selectedColorComponents: [UInt8]?
    private var wheelView: ISColorWheel = ISColorWheel()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        colorView.layer.cornerRadius = 8
        colorView.layer.borderWidth = 2
        colorView.layer.borderColor = UIColor.blackColor().CGColor
        
        wheelView.continuous = true
        wheelView.delegate = self
        
        // Add wheel
        let subview = wheelView
        wheelContainerView.addSubview(subview)
        
        // Refresh
        colorWheelDidChangeColor(wheelView)
    }
  
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        wheelView.frame = wheelContainerView.bounds
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    @IBAction func onBrightnessValueChanged(sender: AnyObject) {
        colorWheelDidChangeColor(wheelView)
    }

    @IBAction func onClickSend(sender: AnyObject) {
    
        if let selectedColorComponents = selectedColorComponents {
            let data = NSMutableData()
            let prefixData = ControllerColorWheelViewController.prefix.dataUsingEncoding(NSUTF8StringEncoding)!
            data.appendData(prefixData)
            for var component in selectedColorComponents {
                data.appendBytes(&component, length: sizeof(UInt8))
            }
            
            UartManager.sharedInstance.sendDataWithCrc(data)
        }
    }
}


// MARK: - ISColorWheelDelegate
extension ControllerColorWheelViewController : ISColorWheelDelegate {
    func colorWheelDidChangeColor(colorWheel:ISColorWheel) {
        
        let colorWheelColor = colorWheel.currentColor
        //sliderGradientView.endColor = colorWheelColor
        
        let brightness = CGFloat(brightnessSlider.value)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        colorWheelColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        red = red*brightness
        green = green*brightness
        blue = blue*brightness
        
        let color = UIColor(red: red, green: green, blue: blue, alpha: 1.0)
        
        colorView.backgroundColor = color
        valueLabel.text = "R: \(Int(255.0 * Float(red)))  G: \(Int(255.0 * Float(green)))  B: \(Int(255.0 * Float(blue)))"
        sliderGradientView.endColor = color
    
        
        selectedColorComponents = [UInt8(255.0 * Float(red)), UInt8(255.0 * Float(green)), UInt8(255.0 * Float(blue))]

    }
}