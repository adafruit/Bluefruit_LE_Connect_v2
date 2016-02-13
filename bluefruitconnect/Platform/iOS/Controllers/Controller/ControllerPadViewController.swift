//
//  ControllerPadViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class ControllerPadViewController: UIViewController {

    //  Constants
    static let prefix = "!B"

    // UI
    @IBOutlet weak var directionsView: UIView!
    @IBOutlet weak var numbersView: UIView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup buttons targets
        for subview in directionsView.subviews {
            if let button = subview as? UIButton {
                setupButton(button)
            }
        }
        
        for subview in numbersView.subviews {
            if let button = subview as? UIButton {
                setupButton(button)
            }
        }
    }
    
    func setupButton(button: UIButton) {
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        
        button.addTarget(self, action: "onTouchDown:", forControlEvents: .TouchDown)
        button.addTarget(self, action: "onTouchUp:", forControlEvents: .TouchUpInside)
        button.addTarget(self, action: "onTouchUp:", forControlEvents: .TouchDragExit)
        button.addTarget(self, action: "onTouchUp:", forControlEvents: .TouchCancel)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func onTouchDown(sender: UIButton) {
        sendTouchEvent(sender.tag, isPressed: true)
    }
    
    func onTouchUp(sender: UIButton) {
        sendTouchEvent(sender.tag, isPressed: false)
    }
    
    private func sendTouchEvent(tag: Int, isPressed: Bool) {
        let message = "!B\(tag)\(isPressed ? "1" : "0"))"
        if let data = message.dataUsingEncoding(NSUTF8StringEncoding) {
            UartManager.sharedInstance.sendDataWithCrc(data)
        }
    }
}
