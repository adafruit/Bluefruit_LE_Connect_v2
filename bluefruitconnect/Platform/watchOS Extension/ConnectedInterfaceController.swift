//
//  ConnectedInterfaceController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 01/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import WatchKit
import Foundation


class ConnectedInterfaceController: WKInterfaceController {

    @IBOutlet var peripheralNameLabel: WKInterfaceLabel!
    @IBOutlet var uartAvailableLabel: WKInterfaceLabel!
    @IBOutlet var uartUnavailableLabel: WKInterfaceLabel!
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        // Update values
        if let appContext = WatchSessionManager.sharedInstance.session?.receivedApplicationContext {
            didReceiveApplicationContext(appContext)
        }
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    // MARK: - Session
    func didReceiveApplicationContext(applicationContext: [String : AnyObject]) {
        DLog("ConnectedInterfaceController didReceiveApplicationContext: \(applicationContext)")
        
        // Name
        var peripheralName = "{No Name}"
        if let name = applicationContext["bleConnectedPeripheralName"] as? String {
            peripheralName = name
        }
        peripheralNameLabel.setText( peripheralName )
        
        // Uart
        let hasUart = applicationContext["bleHasUart"]?.boolValue == true
        uartAvailableLabel.setHidden(!hasUart)
        uartUnavailableLabel.setHidden(hasUart)
    }
}
