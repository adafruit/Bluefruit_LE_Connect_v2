//
//  NeopixelColorPickerViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 27/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit
import iOS_color_wheel

protocol NeopixelColorPickerViewControllerDelegate: class {
    func onColorPickerChooseColor(_ color: UIColor)
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
    fileprivate var selectedColorComponents: [UInt8]?
    private var wheelView: ISColorWheel = ISColorWheel()

    fileprivate var selectedColor = UIColor.white
    weak var delegate: NeopixelColorPickerViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // UI
        colorView.layer.cornerRadius = 8
        colorView.layer.borderWidth = 1
        colorView.layer.borderColor = UIColor.black.cgColor
        
        sliderGradientView.layer.borderWidth = 1
        sliderGradientView.layer.borderColor = UIColor.black.cgColor
        sliderGradientView.layer.cornerRadius = sliderGradientView.bounds.size.height/2
        sliderGradientView.layer.masksToBounds = true
        
        brightnessSlider.setMinimumTrackImage(UIImage(), for: .normal)
        brightnessSlider.setMaximumTrackImage(UIImage(), for: .normal)
        
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
    @IBAction func onBrightnessValueChanged(_ sender: AnyObject) {
        colorWheelDidChangeColor(wheelView)
    }
    
    @IBAction func onClickSend(_ sender: AnyObject) {
        delegate?.onColorPickerChooseColor(selectedColor)
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onClickDone(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - ISColorWheelDelegate
extension NeopixelColorPickerViewController : ISColorWheelDelegate {
    func colorWheelDidChangeColor(_ colorWheel:ISColorWheel) {
        
        let colorWheelColor = colorWheel.currentColor
        
        let brightness = CGFloat(brightnessSlider.value)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        colorWheelColor().getRed(&red, green: &green, blue: &blue, alpha: nil)
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
