//
//  PeripheralList.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 05/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

class PeripheralList {
    private var lastUserSelectionTime = CFAbsoluteTimeGetCurrent()
    private var selectedPeripheralIdentifier : String?
    
    var blePeripherals : [String] {
        return BleManager.sharedInstance.blePeripheralFoundAlphabeticKeys()
    }
    
    var selectedPeripheralRow: Int? {
        return indexOfPeripheralIdentifier(selectedPeripheralIdentifier)
    }
    
    var elapsedTimeSinceSelection : CFAbsoluteTime {
        return CFAbsoluteTimeGetCurrent() - self.lastUserSelectionTime
    }
    
    func indexOfPeripheralIdentifier(identifier : String?) -> Int? {
        var result : Int?
        if let identifier = identifier {
            result = blePeripherals.indexOf(identifier)
        }
        
        return result
    }
    
    func disconnected() {
        // Check that is really disconnected
        if BleManager.sharedInstance.blePeripheralConnected == nil {
            selectedPeripheralIdentifier = nil
           // DLog("Peripheral selected row: -1")
            
        }
    }
    
    func connectToPeripheral(identifier : String?) {
        let bleManager = BleManager.sharedInstance
        
        if (identifier != bleManager.blePeripheralConnected?.peripheral.identifier.UUIDString || identifier == nil) {
            
            //
            let blePeripheralsFound = bleManager.blePeripherals()
            lastUserSelectionTime = CFAbsoluteTimeGetCurrent()
            
            // Disconnect from previous
            if let selectedRow = selectedPeripheralRow {
                let peripherals = blePeripherals
                if selectedRow < peripherals.count {      // To avoid problems with peripherals disconnecting
                    let selectedBlePeripheralIdentifier = peripherals[selectedRow];
                    let blePeripheral = blePeripheralsFound[selectedBlePeripheralIdentifier]!
                    
                    BleManager.sharedInstance.disconnect(blePeripheral)
                }
                //DLog("Peripheral selected row: -1")
                selectedPeripheralIdentifier = nil
            }
            
            // Connect to new peripheral
            if let selectedBlePeripheralIdentifier = identifier {
                
                let blePeripheral = blePeripheralsFound[selectedBlePeripheralIdentifier]!
                if (BleManager.sharedInstance.blePeripheralConnected?.peripheral.identifier != selectedBlePeripheralIdentifier) {
                    // DLog("connect to new peripheral: \(selectedPeripheralIdentifier)")
                    
                    BleManager.sharedInstance.connect(blePeripheral)
                    
                    selectedPeripheralIdentifier = selectedBlePeripheralIdentifier
                }
            }
            else {
                //DLog("Peripheral selected row: -1")
                selectedPeripheralIdentifier = nil;
            }
        }
    }
    
    func selectRow(row : Int ) {
        if (row != selectedPeripheralRow) {
            //DLog("Peripheral selected row: \(row)")
            connectToPeripheral(row >= 0 ? blePeripherals[row] : nil)
        }
    }
}