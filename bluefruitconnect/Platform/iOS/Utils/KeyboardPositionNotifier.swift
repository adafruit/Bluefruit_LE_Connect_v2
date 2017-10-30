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
        registerKeyboardNotifications(enable: true)
    }
    
    deinit {
        registerKeyboardNotifications(enable: false)
    }
    
    func registerKeyboardNotifications(enable : Bool) {
        let notificationCenter = NotificationCenter.default
        if (enable) {
            notificationCenter.addObserver(self, selector: #selector(KeyboardPositionNotifier.keyboardWillBeShown), name: .UIKeyboardWillShow, object: nil)
            notificationCenter.addObserver(self, selector: #selector(KeyboardPositionNotifier.keyboardWillBeHidden), name: .UIKeyboardWillHide, object: nil)
        } else {
            notificationCenter.removeObserver(self, name: .UIKeyboardWillShow, object: nil)
            notificationCenter.removeObserver(self, name: .UIKeyboardWillHide, object: nil)
        }
    }
    
    @objc func keyboardWillBeShown(notification : NSNotification) {
        var info = notification.userInfo!
        let keyboardFrame: CGRect = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
       
        keyboardPositionChanged(keyboardFrame: keyboardFrame, keyboardShown: true)
    }
  
  @objc func keyboardWillBeHidden(notification : NSNotification) {
      keyboardPositionChanged(keyboardFrame: CGRect.zero, keyboardShown: false)
    }
    
    func keyboardPositionChanged(keyboardFrame : CGRect, keyboardShown : Bool) {
        delegate?.onKeyboardPositionChanged(keyboardFrame: keyboardFrame, keyboardShown: keyboardShown)
    }
}




