//
//  ColorRGBInterfaceController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 02/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import WatchKit
import Foundation

class ColorRGBInterfaceController: WKInterfaceController {
    @IBOutlet var rgbColorSwatch: WKInterfaceGroup?
    @IBOutlet var rSlider: WKInterfaceSlider?
    @IBOutlet var gSlider: WKInterfaceSlider?
    @IBOutlet var bSlider: WKInterfaceSlider?

    var swatchColor = UIColor.gray

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        // Configure interface objects here.
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    @IBAction func rSliderChanged(_ value: Float) {

        //retrieve rgb color vals from swatch
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        swatchColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let newColor = UIColor(red: CGFloat(value), green: green, blue: blue, alpha: 1.0)
        setRGBColor(newColor)
    }

    @IBAction func gSliderChanged(_ value: Float) {

        //retrieve rgb color vals from swatch
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        swatchColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let newColor = UIColor(red: red, green: CGFloat(value), blue: blue, alpha: 1.0)
        setRGBColor(newColor)

    }

    @IBAction func bSliderChanged(_ value: Float) {

        //retrieve rgb color vals from swatch
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        swatchColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let newColor = UIColor(red: red, green: green, blue: CGFloat(value), alpha: 1.0)
        setRGBColor(newColor)
    }

    private func setRGBColor(_ newColor: UIColor) {

        swatchColor = newColor
        rgbColorSwatch?.setBackgroundColor(swatchColor)
    }

    @IBAction func onClickSend() {
        guard let session = WatchSessionManager.sharedInstance.session else { return }

        let hex = colorHexInt(swatchColor)
        session.sendMessage(["command": "color", "color": hex], replyHandler: nil) { (error) in
            DLog("colorRGB error: \(error)")
        }
    }
}
