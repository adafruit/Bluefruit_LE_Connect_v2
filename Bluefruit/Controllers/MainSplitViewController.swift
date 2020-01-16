//
//  MainSplitViewController.swift
//  Bluefruit
//
//  Created by Antonio García on 16/05/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class MainSplitViewController: UISplitViewController {

    // Data
    private weak var didDisconnectFromPeripheralObserver: NSObjectProtocol?

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set UISplitViewController delegate
        self.delegate = self

        // Hack to hide the white split divider
        self.view.backgroundColor = UIColor.darkGray

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


    // MARK: - Notifications
    fileprivate func didDisconnectFromPeripheral(notification: Notification) {
        //DLog("main: disconnection")

        // Show disconnected alert (if no previous alert is shown)
        if self.presentedViewController == nil {
            peripheralDidDisconnect()
        } else {
            DLog("dismissing presenting viewcontroller before handling disconnect...")
            self.presentingViewController?.dismiss(animated: true) { [unowned self] in
                self.peripheralDidDisconnect()
            }
            //            DLog("disconnection detected but cannot go to periperalList because there is a presentedViewController on screen")
        }
    }

    private func peripheralDidDisconnect() {
        let isLastConnectedPeripheral = BleManager.shared.connectedPeripherals().count == 0
        let localizationManager = LocalizationManager.shared
        let alertController = UIAlertController(title: nil, message: localizationManager.localizedString("scanner_peripheraldisconnected"), preferredStyle: .alert)
        let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler: { [weak self] _ in
            guard let context = self else { return }

            if isLastConnectedPeripheral {
                let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
                if isFullScreen {
                    (context.viewControllers.first as? UINavigationController)?.popToRootViewController(animated: true)
                } else {
                    let detailViewController: UIViewController? = context.viewControllers.count > 1 ? context.viewControllers[1] : nil

                    if let navigationController = detailViewController as? UINavigationController {
                        navigationController.popToRootViewController(animated: false)       // pop any viewcontrollers (like ControlPad)
                                                
                        if let peripheralModulesViewController = navigationController.viewControllers.first as? PeripheralModulesViewController {
                            peripheralModulesViewController.showEmpty(true)
                            peripheralModulesViewController.setConnecting(false)
                        }
                        
                    }
                }
            }
        })
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
}

// MARK: - UISplitViewControllerDelegate
extension MainSplitViewController: UISplitViewControllerDelegate {

    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {

        let connectedPeripherals = BleManager.shared.connectedPeripherals()
        return connectedPeripherals.isEmpty
    }
}
