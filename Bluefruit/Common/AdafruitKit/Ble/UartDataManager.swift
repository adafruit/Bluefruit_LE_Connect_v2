//
//  UartDataManager.swift
//  Calibration
//
//  Created by Antonio García on 20/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

protocol UartDataManagerDelegate: class {
    func onUartRx(data: Data)
}

// Basic Uart Managemnet. Use it to cache all data received and help parsint it
class UartDataManager {
    
    // Data
    var enabled: Bool = false  {
        didSet {
            if enabled != oldValue {
                registerNotifications(enabled: enabled)
            }
        }
    }
    weak var delegate: UartDataManagerDelegate?
    fileprivate var rxData = Data()
    fileprivate var rxDataSemaphore = DispatchSemaphore(value: 1)
    
    init(delegate: UartDataManagerDelegate?) {
        self.delegate = delegate
        
        enabled = true
    }
    
    deinit {
        enabled = false
    }
    
    // MARK: - BLE Notifications
    var didConnectToPeripheralObserver: NSObjectProtocol?
    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            didConnectToPeripheralObserver = notificationCenter.addObserver(forName: .didConnectToPeripheral, object: nil, queue: OperationQueue.main, using: didConnectToPeripheral)
        }
        else {
            if let didConnectToPeripheralObserver = didConnectToPeripheralObserver {notificationCenter.removeObserver(didConnectToPeripheralObserver)}
        }
    }
    
    private func didConnectToPeripheral(notification: Notification) {
        clearRxCache()
    }
    
    // MARK: - Send data
    func send(blePeripheral: BlePeripheral, data: Data?, completion: ((Error?) -> Void)? = nil) {
        blePeripheral.uartSend(data: data, completion: completion)
    }
    
    // MARK: - Received data
    func rxDataReceived(data: Data?, error: Error?) {
        
        guard error == nil else {
            DLog("rxDataReceived error: \(error!)")
            return
        }
        
        guard let data = data else {
            return
        }
        
        rxDataSemaphore.wait()            // don't append more data, till the delegate has finished processing it
        rxData.append(data)
        
        // Send data to delegate
        delegate?.onUartRx(data: rxData)
        
        //DLog("cachedRxData: \(cachedRxData.count)")
        
        rxDataSemaphore.signal()
    }
    
    func clearRxCache() {
        rxData.removeAll()
    }
    
    func removeRxCacheFirst(n: Int) {
        if n <= rxData.count {
            rxData.removeFirst(n)
        }
        else {
            clearRxCache()
        }
    }
    
    func flushRxCache() {
        if rxData.count > 0 {
            rxDataSemaphore.wait()
            delegate?.onUartRx(data: rxData)
            rxDataSemaphore.signal()
        }
    }
}
