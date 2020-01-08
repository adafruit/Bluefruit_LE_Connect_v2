//
//  AlertHelper.swift
//  Bluefruit
//
//  Created by Antonio García on 18/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

func showErrorAlert(from controller: UIViewController, title: String?, message: String?, okHandler: ((UIAlertAction) -> Void)? = nil) {

    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
    let okAction = UIAlertAction(title: "Ok", style: .default, handler: okHandler)
    alertController.addAction(okAction)
    controller.present(alertController, animated: true, completion: nil)
}
