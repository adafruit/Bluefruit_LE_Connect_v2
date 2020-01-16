//
//  MagnetometerPageContentViewController.swift
//  Calibration
//
//  Created by Antonio on 09/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

protocol MagnetometerPageContentViewControllerDelegate: class {
    func onMagnetometerRestart()
    func onMagnetometerParametersChanged()
}

class MagnetometerPageContentViewController: PageContentViewController {

    var calibration: Calibration!
    weak var delegate: MagnetometerPageContentViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
