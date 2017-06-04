//
//  GyroscopePageContentViewController.swift
//  Calibration
//
//  Created by Antonio on 09/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

protocol GyroscopePageContentViewControllerDelegate: class {
    func onGyroscopeRestart()
    func onGyroscopeParametersChanged()
}

class GyroscopePageContentViewController: PageContentViewController {

    var progress: Float = 0
    var gyroVector: Vector3!
//    var calibration: Calibration!
    weak var delegate: GyroscopePageContentViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
