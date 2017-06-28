//
//  ControllerColorWheelViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit
//import iOS_color_wheel

protocol ControllerColorWheelViewControllerDelegate: class {
    func onSendColorComponents(_ colorComponents: [UInt8])
}

class ControllerColorWheelViewController: UIViewController {

    //  Constants 
    static let prefix = "!C"

    // UI
    @IBOutlet weak var wheelContainerView: UIView!
    @IBOutlet weak var brightnessSlider: UISlider!
    @IBOutlet weak var colorView: UIView!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var hexValueLabel: UILabel!
    @IBOutlet weak var sliderGradientView: GradientView!

    // Data
    weak var delegate: ControllerColorWheelViewControllerDelegate?

    fileprivate var selectedColorComponents: [UInt8]?
    private var wheelView: ISColorWheel = ISColorWheel()

    override func viewDidLoad() {
        super.viewDidLoad()

        // UI
        colorView.layer.cornerRadius = 8
        colorView.layer.borderWidth = 2
        colorView.layer.borderColor = UIColor.black.cgColor

        sliderGradientView.layer.borderWidth = 2
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

        if let delegate = delegate, let selectedColorComponents = selectedColorComponents {
            delegate.onSendColorComponents(selectedColorComponents)
        }
    }

    @IBAction func onClickHelp(_ sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.sharedInstance
        let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
        helpViewController.setHelp(localizationManager.localizedString("colorpicker_help_text"), title: localizationManager.localizedString("colorpicker_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender

        present(helpNavigationController, animated: true, completion: nil)
    }
}

// MARK: - ISColorWheelDelegate
extension ControllerColorWheelViewController: ISColorWheelDelegate {
    func colorWheelDidChangeColor(_ colorWheel: ISColorWheel) {

        guard let colorWheelColor = colorWheel.currentColor() else { return }

        let brightness = CGFloat(brightnessSlider.value)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        colorWheelColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        red = red*brightness
        green = green*brightness
        blue = blue*brightness

        let color = UIColor(red: red, green: green, blue: blue, alpha: 1.0)

        colorView.backgroundColor = color
        valueLabel.text = "R: \(Int(255.0 * Float(red)))  G: \(Int(255.0 * Float(green)))  B: \(Int(255.0 * Float(blue)))"
        let hexString = colorHexString(color)
        hexValueLabel.text = "Hex: \(hexString)"
        sliderGradientView.endColor = color

        selectedColorComponents = [UInt8(255.0 * Float(red)), UInt8(255.0 * Float(green)), UInt8(255.0 * Float(blue))]
    }

}
