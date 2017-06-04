//
//  KeyboardPositionNotifier.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Antonio García on 30/07/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import UIKit

protocol KeyboardPositionNotifierDelegate: class {
    func onKeyboardPositionChanged(keyboardFrame: CGRect, keyboardShown: Bool)
}

class KeyboardPositionNotifier: NSObject {

    weak var delegate: KeyboardPositionNotifierDelegate?

    override init() {
        super.init()
        registerNotifications(enabled: true)
    }

    deinit {
        registerNotifications(enabled: false)
    }

    // MARK: - BLE Notifications
    private weak var keyboardWillBeShownObserver: NSObjectProtocol?
    private weak var keyboardWillBeHiddenObserver: NSObjectProtocol?

    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            keyboardWillBeShownObserver = notificationCenter.addObserver(forName: NSNotification.Name.UIKeyboardWillShow, object: nil, queue: .main, using: keyboardWillBeShown)
            keyboardWillBeHiddenObserver = notificationCenter.addObserver(forName: NSNotification.Name.UIKeyboardWillHide, object: nil, queue: .main, using: keyboardWillBeHidden)
        } else {
            if let keyboardWillBeShownObserver = keyboardWillBeShownObserver {notificationCenter.removeObserver(keyboardWillBeShownObserver)}
            if let keyboardWillBeHiddenObserver = keyboardWillBeHiddenObserver {notificationCenter.removeObserver(keyboardWillBeHiddenObserver)}
        }
    }

    private func keyboardWillBeShown(notification: Notification) {
        var info = notification.userInfo!
        let keyboardFrame: CGRect = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue

        keyboardPositionChanged(keyboardFrame: keyboardFrame, keyboardShown: true)
    }

    private func keyboardWillBeHidden(notification: Notification) {
        keyboardPositionChanged(keyboardFrame: CGRect(), keyboardShown: false)
    }

    private func keyboardPositionChanged(keyboardFrame: CGRect, keyboardShown: Bool) {
        delegate?.onKeyboardPositionChanged(keyboardFrame: keyboardFrame, keyboardShown: keyboardShown)
    }
}
