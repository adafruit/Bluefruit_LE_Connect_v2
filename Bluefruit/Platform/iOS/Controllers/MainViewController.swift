//
//  MainViewController.swift
//  Bluefruit
//
//  Created by Antonio García on 16/05/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit


class MainViewController: UISplitViewController {

    private weak var didDisconnectFromPeripheralObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Disconnect detection should work even when the viewcontroller is not shown
        didDisconnectFromPeripheralObserver = NotificationCenter.default.addObserver(forName: .didDisconnectFromPeripheral, object: nil, queue: .main, using: didDisconnectFromPeripheral)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
       
    deinit {
        if let didDisconnectFromPeripheralObserver = didDisconnectFromPeripheralObserver {NotificationCenter.default.removeObserver(didDisconnectFromPeripheralObserver)}

    }

    fileprivate func didDisconnectFromPeripheral(notification: Notification) {
        DLog("main: disconnection")
        let isLastConnectedPeripheral = BleManager.sharedInstance.connectedPeripherals().count == 0
        
        // Show disconnected alert (if no previous alert is shown)
        if self.presentedViewController == nil {
            let localizationManager = LocalizationManager.sharedInstance
            let alertController = UIAlertController(title: nil, message: localizationManager.localizedString("peripherallist_peripheraldisconnected"), preferredStyle: .alert)
            let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler: { [weak self] (_) -> Void in
                guard let context = self else { return }
                
                if isLastConnectedPeripheral {
                    let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
                    if isFullScreen {
                       (context.viewControllers.first as? UINavigationController)?.popToRootViewController(animated: true)
                    }
                    else {
                        let detailViewController: UIViewController? = context.viewControllers.count > 1 ? context.viewControllers[1] : nil
                        if let navigationController = detailViewController as? UINavigationController {
                            navigationController.popToRootViewController(animated: false)       // pop any viewcontrollers (like ControlPad)
                            
                            if let peripheralDetailsViewController = navigationController.viewControllers.first as? PeripheralDetailsViewController {
                                peripheralDetailsViewController.showEmpty(true)
                                peripheralDetailsViewController.setConnecting(false)
                            }
                        }
 
                    }
                }
            })
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
        }
        else {
            DLog("disconnection detected but cannot go to periperalList because there is a presentedViewController on screen")
        }
    }
}
