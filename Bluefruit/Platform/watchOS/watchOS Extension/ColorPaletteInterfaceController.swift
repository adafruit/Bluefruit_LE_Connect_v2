//
//  ColorPaletteInterfaceController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 01/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import WatchKit
import Foundation

class ColorPaletteInterfaceController: WKInterfaceController {

    // Constants
    private static let palette: [UIColor] = [
        UIColor(red:0.969, green:0.400, blue:0.427, alpha:1.000),
        UIColor(red:0.992, green:0.694, blue:0.427, alpha:1.000),
        UIColor(red:1.000, green:1.000, blue:0.694, alpha:1.000),

        UIColor(red:1.000, green:0.000, blue:0.000, alpha:1.000),
        UIColor(red:1.000, green:0.502, blue:0.000, alpha:1.000),
        UIColor(red:1.000, green:1.000, blue:0.004, alpha:1.000),

        UIColor(red:0.686, green:0.000, blue:0.051, alpha:1.000),
        UIColor(red:0.686, green:0.184, blue:0.039, alpha:1.000),
        UIColor(red:0.667, green:0.714, blue:0.047, alpha:1.000),

        UIColor(red:0.706, green:1.000, blue:0.698, alpha:1.000),
        UIColor(red:0.706, green:1.000, blue:1.000, alpha:1.000),
        UIColor(red:0.500, green:0.500, blue:1.000, alpha:1.000),

        UIColor(red:0.000, green:1.000, blue:0.000, alpha:1.000),
        UIColor(red:0.004, green:1.000, blue:1.000, alpha:1.000),
        UIColor(red:0.000, green:0.000, blue:1.000, alpha:1.000),

        UIColor(red:0.137, green:0.718, blue:0.024, alpha:1.000),
        UIColor(red:0.122, green:0.702, blue:0.671, alpha:1.000),
        UIColor(red:0.000, green:0.000, blue:0.694, alpha:1.000),

        UIColor(red:0.847, green:0.682, blue:0.996, alpha:1.000),
        UIColor(red:0.992, green:0.678, blue:1.000, alpha:1.000),
        UIColor(red:1.000, green:1.000, blue:1.000, alpha:1.000),

        UIColor(red:0.518, green:0.000, blue:0.996, alpha:1.000),
        UIColor(red:0.984, green:0.000, blue:1.000, alpha:1.000),
        UIColor(red:0.502, green:0.502, blue:0.502, alpha:1.000),

        UIColor(red:0.271, green:0.000, blue:0.698, alpha:1.000),
        UIColor(red:0.682, green:0.000, blue:0.690, alpha:1.000),
        UIColor(red:0.000, green:0.000, blue:0.000, alpha:1.000)
    ]

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

    @IBAction func onClickColor0() {
        onClickColor(0)
    }

    @IBAction func onClickColor1() {
        onClickColor(1)
    }

    @IBAction func onClickColor2() {
        onClickColor(2)
    }

    @IBAction func onClickColor3() {
        onClickColor(3)
    }

    @IBAction func onClickColor4() {
        onClickColor(4)
    }

    @IBAction func onClickColor5() {
        onClickColor(5)
    }

    @IBAction func onClickColor6() {
        onClickColor(6)
    }

    @IBAction func onClickColor7() {
        onClickColor(7)
    }

    @IBAction func onClickColor8() {
        onClickColor(8)
    }

    @IBAction func onClickColor9() {
        onClickColor(9)
    }

    @IBAction func onClickColor10() {
        onClickColor(10)
    }

    @IBAction func onClickColor11() {
        onClickColor(11)
    }

    @IBAction func onClickColor12() {
        onClickColor(12)
    }

    @IBAction func onClickColor13() {
        onClickColor(13)
    }

    @IBAction func onClickColor14() {
        onClickColor(14)
    }

    @IBAction func onClickColor15() {
        onClickColor(15)
    }

    @IBAction func onClickColor16() {
        onClickColor(16)
    }

    @IBAction func onClickColor17() {
        onClickColor(17)
    }

    @IBAction func onClickColor18() {
        onClickColor(18)
    }

    @IBAction func onClickColor19() {
        onClickColor(19)
    }

    @IBAction func onClickColor20() {
        onClickColor(20)
    }

    @IBAction func onClickColor21() {
        onClickColor(21)
    }

    @IBAction func onClickColor22() {
        onClickColor(22)
    }

    @IBAction func onClickColor23() {
        onClickColor(23)
    }

    @IBAction func onClickColor24() {
        onClickColor(24)
    }

    @IBAction func onClickColor25() {
        onClickColor(25)
    }

    @IBAction func onClickColor26() {
        onClickColor(26)
    }

    private func onClickColor(_ tag: Int) {
        guard let session = WatchSessionManager.sharedInstance.session else { return }

        let color = ColorPaletteInterfaceController.palette[tag]
        let hex = colorHexInt(color)
        session.sendMessage(["command": "color", "color": hex], replyHandler: nil) { (error) in
            DLog("colorPalette error: \(error)")
        }
    }
}
