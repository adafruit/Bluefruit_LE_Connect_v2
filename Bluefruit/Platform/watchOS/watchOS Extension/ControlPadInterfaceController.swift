//
//  ControlPadArrowsInterfaceController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 01/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import WatchKit
import Foundation

class ControlPadInterfaceController: WKInterfaceController {

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

    @IBAction func onClickButton1() {
        onClickControlPadButton(1)
    }

    @IBAction func onClickButton2() {
        onClickControlPadButton(2)
    }

    @IBAction func onClickButton3() {
        onClickControlPadButton(3)
    }

    @IBAction func onClickButton4() {
        onClickControlPadButton(4)
    }

    @IBAction func onClickLeftArrow() {
        onClickControlPadButton(7)
    }

    @IBAction func onClickRightArrow() {
        onClickControlPadButton(8)
    }

    @IBAction func onClickUpArrow() {
        onClickControlPadButton(5)
    }

    @IBAction func onClickDownArrow() {
        onClickControlPadButton(6)
    }

    private func onClickControlPadButton(_ tag: Int) {
        if let session = WatchSessionManager.sharedInstance.session {
            session.sendMessage(["command": "controlPad", "tag": tag], replyHandler: nil) { (error) in
                DLog("controlPad error: \(error)")
            }
        }
    }
}
