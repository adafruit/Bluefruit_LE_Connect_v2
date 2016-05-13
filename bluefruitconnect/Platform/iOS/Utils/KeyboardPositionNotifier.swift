//
//  KeyboardPositionNotifier.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Antonio García on 30/07/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import UIKit

protocol KeyboardPositionNotifierDelegate: class {
    func onKeyboardPositionChanged(keyboardFrame : CGRect, keyboardShown : Bool)
}

class KeyboardPositionNotifier: NSObject {
    
    weak var delegate : KeyboardPositionNotifierDelegate?

    override init() {
        super.init()
        registerKeyboardNotifications(true)
    }
    
    deinit {
        registerKeyboardNotifications(false)
    }
    
    func registerKeyboardNotifications(enable : Bool) {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        if (enable) {
            notificationCenter.addObserver(self, selector: #selector(KeyboardPositionNotifier.keyboardWillBeShown(_:)), name: UIKeyboardWillShowNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(KeyboardPositionNotifier.keyboardWillBeHidden(_:)), name: UIKeyboardWillHideNotification, object: nil)
        } else {
            notificationCenter.removeObserver(self, name: UIKeyboardWillShowNotification, object: nil)
            notificationCenter.removeObserver(self, name: UIKeyboardWillHideNotification, object: nil)
        }
    }
    
    func keyboardWillBeShown(notification : NSNotification) {
        var info = notification.userInfo!
        let keyboardFrame: CGRect = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
       
        keyboardPositionChanged(keyboardFrame, keyboardShown: true)
    }
    
    func keyboardWillBeHidden(notification : NSNotification) {
       keyboardPositionChanged(CGRectZero, keyboardShown: false)
    }
    
    func keyboardPositionChanged(keyboardFrame : CGRect, keyboardShown : Bool) {
        delegate?.onKeyboardPositionChanged(keyboardFrame, keyboardShown: keyboardShown)
    }
}
