//
//  NeopixelColorPickerViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 27/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit
//import iOS_color_wheel

protocol NeopixelColorPickerViewControllerDelegate: class {
    func onColorPickerChooseColor(colorPickerViewController: NeopixelColorPickerViewController, color: UIColor, wComponent: Float)
}

class NeopixelColorPickerViewController: UIViewController {
    // UI
    @IBOutlet weak var wheelContainerView: UIView!
    @IBOutlet weak var brightnessSlider: UISlider!
    @IBOutlet weak var wComponentSlider: UISlider!
    @IBOutlet weak var colorView: UIView!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var hexValueLabel: UILabel!
    @IBOutlet weak var sliderGradientView: GradientView!
    @IBOutlet weak var brightnessLabel: UILabel!
    @IBOutlet weak var wComponentGradientView: GradientView!
    @IBOutlet weak var wComponentLabel: UILabel!
    @IBOutlet weak var wComponentSliderContainerView: UIView!
    @IBOutlet weak var wComponentColorView: UIView!

    // Params
    var is4ComponentsEnabled = false
    var initialColor: UIColor?
    var initialBrightness: Float?
    var initialWComponent: Float?

    // Data
    fileprivate var selectedColorComponents: [UInt8]?
    private var wheelView: ISColorWheel = ISColorWheel()

    fileprivate var selectedColor = UIColor.white
    fileprivate var selectedWComponent: Float = 0
    weak var delegate: NeopixelColorPickerViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        // UI
        colorView.layer.cornerRadius = 8
        colorView.layer.borderWidth = 1
        colorView.layer.borderColor = UIColor.black.cgColor
        colorView.layer.masksToBounds = true

        sliderGradientView.layer.borderWidth = 1
        sliderGradientView.layer.borderColor = UIColor.black.cgColor
        sliderGradientView.layer.cornerRadius = sliderGradientView.bounds.size.height/2
        sliderGradientView.layer.masksToBounds = true

        brightnessSlider.setMinimumTrackImage(UIImage(), for: .normal)
        brightnessSlider.setMaximumTrackImage(UIImage(), for: .normal)

        wComponentGradientView.layer.borderWidth = 1
        wComponentGradientView.layer.borderColor = UIColor.black.cgColor
        wComponentGradientView.layer.cornerRadius = sliderGradientView.bounds.size.height/2
        wComponentGradientView.layer.masksToBounds = true

        wComponentSlider.setMinimumTrackImage(UIImage(), for: .normal)
        wComponentSlider.setMaximumTrackImage(UIImage(), for: .normal)

        // Setup wheel view
        wheelView.continuous = true
        wheelView.delegate = self

        // Add wheel
        let subview = wheelView
        wheelContainerView.addSubview(subview)

        // Components
        wComponentLabel.isHidden = !is4ComponentsEnabled
        wComponentSliderContainerView.isHidden = !is4ComponentsEnabled
        wComponentColorView.isHidden = !is4ComponentsEnabled

        // Localization
        let localizationManager = LocalizationManager.shared
         self.title = localizationManager.localizedString("colorpicker_title")
        brightnessLabel.text = localizationManager.localizedString("colorpicker_brightness")
        wComponentLabel.text = localizationManager.localizedString("colorpicker_wcomponent")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let currentColor = initialColor {
            wheelView.frame = wheelContainerView.bounds
            wheelView.layoutIfNeeded()
            DispatchQueue.main.async {
                self.wheelView.setCurrentColor(currentColor)
                if let brightness = self.initialBrightness {
                    self.brightnessSlider.value = brightness
                }
                if let wComponent = self.initialWComponent {
                    self.wComponentSlider.value = wComponent
                }
                self.colorWheelDidChangeColor(self.wheelView)
            }
        }
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

    @IBAction func onWComponentValueChanged(_ sender: Any) {
        colorWheelDidChangeColor(wheelView)
    }

    @IBAction func onClickSend(_ sender: AnyObject) {
        delegate?.onColorPickerChooseColor(colorPickerViewController: self, color: selectedColor, wComponent: selectedWComponent)
        dismiss(animated: true, completion: nil)
    }

    @IBAction func onClickDone(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    func colorWheelColor() -> UIColor {
        return wheelView.currentColor()!
    }
    
    func colorWheelBrightness() -> Float {
        return brightnessSlider.value
    }
}

// MARK: - ISColorWheelDelegate
extension NeopixelColorPickerViewController: ISColorWheelDelegate {
    func colorWheelDidChangeColor(_ colorWheel: ISColorWheel) {

        let colorWheelColor = colorWheel.currentColor()!

        let brightness = CGFloat(brightnessSlider.value)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        colorWheelColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        red = red*brightness
        green = green*brightness
        blue = blue*brightness

        let color = UIColor(red: red, green: green, blue: blue, alpha: 1.0)

        colorView.backgroundColor = color
        let wComponent = wComponentSlider.value
        wComponentColorView.backgroundColor = UIColor(red: CGFloat(wComponent), green: CGFloat(wComponent), blue: CGFloat(wComponent), alpha: 1.0)

        let redByte = UInt8(255.0 * Float(red))
        let greendByte = UInt8(255.0 * Float(green))
        let blueByte = UInt8(255.0 * Float(blue))
        let rgbHexString = colorHexString(color)

        let localizationManager = LocalizationManager.shared
        if is4ComponentsEnabled {
            let wByte = UInt8(255.0 * Float(wComponent))
            let wHex = String(format:"%02X", wByte)
            valueLabel.text = String(format: localizationManager.localizedString("colorpicker_rgbw_format"), redByte, greendByte, blueByte, wByte)
            hexValueLabel.text = String(format: localizationManager.localizedString("colorpicker_hex_format"), "\(rgbHexString)\(wHex)")
        } else {
            valueLabel.text = String(format: localizationManager.localizedString("colorpicker_rgb_format"), redByte, greendByte, blueByte)
            hexValueLabel.text = String(format: localizationManager.localizedString("colorpicker_hex_format"), rgbHexString)
        }

        sliderGradientView.endColor = color

        selectedColor = color
        selectedWComponent = wComponent
    }
}
