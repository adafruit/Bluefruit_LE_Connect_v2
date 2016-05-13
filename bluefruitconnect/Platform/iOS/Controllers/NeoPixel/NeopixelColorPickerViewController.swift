//
//  NeopixelColorPickerViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 27/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

protocol NeopixelColorPickerViewControllerDelegate: class {
    func onColorPickerChooseColor(color: UIColor)
}

class NeopixelColorPickerViewController: UIViewController {
    // UI
    @IBOutlet weak var wheelContainerView: UIView!
    @IBOutlet weak var brightnessSlider: UISlider!
    @IBOutlet weak var colorView: UIView!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var hexValueLabel: UILabel!
    @IBOutlet weak var sliderGradientView: GradientView!

    // Data
    private var selectedColorComponents: [UInt8]?
    private var wheelView: ISColorWheel = ISColorWheel()

    private var selectedColor = UIColor.whiteColor()
    weak var delegate: NeopixelColorPickerViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // UI
        colorView.layer.cornerRadius = 8
        colorView.layer.borderWidth = 2
        colorView.layer.borderColor = UIColor.blackColor().CGColor
        
        sliderGradientView.layer.borderWidth = 2
        sliderGradientView.layer.borderColor = UIColor.blackColor().CGColor
        sliderGradientView.layer.cornerRadius = sliderGradientView.bounds.size.height/2
        sliderGradientView.layer.masksToBounds = true
        
        brightnessSlider.setMinimumTrackImage(UIImage(), forState: .Normal)
        brightnessSlider.setMaximumTrackImage(UIImage(), forState: .Normal)
        
        // Setup wheel view
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
    
    // MARK: - Actions
    @IBAction func onBrightnessValueChanged(sender: AnyObject) {
        colorWheelDidChangeColor(wheelView)
    }
    
    @IBAction func onClickSend(sender: AnyObject) {
        delegate?.onColorPickerChooseColor(selectedColor)
        dismissViewControllerAnimated(true, completion: nil)
    }

}



// MARK: - ISColorWheelDelegate
extension NeopixelColorPickerViewController : ISColorWheelDelegate {
    func colorWheelDidChangeColor(colorWheel:ISColorWheel) {
        
        let colorWheelColor = colorWheel.currentColor
        
        let brightness = CGFloat(brightnessSlider.value)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        colorWheelColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        red = red*brightness
        green = green*brightness
        blue = blue*brightness
        
        let color = UIColor(red: red, green: green, blue: blue, alpha: 1.0)
        
        colorView.backgroundColor = color
        valueLabel.text = "RGB: \(Int(255.0 * Float(red)))-\(Int(255.0 * Float(green)))-\(Int(255.0 * Float(blue)))"
        let hexString = colorHexString(color)
        hexValueLabel.text = "Hex: \(hexString)"
        sliderGradientView.endColor = color
        
        selectedColor = color
    }
    
 
}