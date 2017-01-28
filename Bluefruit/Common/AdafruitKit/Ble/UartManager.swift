//
//  UartManager.swift
//  Calibration
//
//  Created by Antonio García on 20/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

protocol UartDelegate: class {
    func onUartRx(data: Data)
}

class UartManager {
    
    // Singleton
    static let sharedInstance = UartManager()
    
    // Data
    weak var delegate: UartDelegate?
    fileprivate var cachedRxData = Data()
    fileprivate var cachedRxDataSemaphore = DispatchSemaphore(value: 1)
    
    init() {
        registerNotifications(enabled: true)

        #if DEBUG
        //cachedRxData = "Test".data(using: .utf8)!
        #endif
    }
    
    deinit {
        registerNotifications(enabled: false)
    }
    
    // MARK: - BLE Notifications
    private func registerNotifications(enabled: Bool) {
        struct Holder {
            static var didConnectToPeripheralObserver: NSObjectProtocol?
        }
        
        if enabled {
            Holder.didConnectToPeripheralObserver = NotificationCenter.default.addObserver(forName: .didConnectToPeripheral, object: nil, queue: OperationQueue.main, using: didConnectToPeripheral)
        }
        else {
            if let didConnectToPeripheralObserver = Holder.didConnectToPeripheralObserver {NotificationCenter.default.removeObserver(didConnectToPeripheralObserver)}
        }
    }
    
    private func didConnectToPeripheral(notification: Notification) {
        clearRxCache()
    }

    // MARK: - Received data
    func uartRxDataReceived(data: Data?, error: Error?) {
        
        guard error == nil else {
            DLog("uartRxDataReceived error: \(error!)")
            return
        }

        guard let data = data else {
            return
        }

        cachedRxDataSemaphore.wait()            // don't append more data, till the delegate has finished processing it
        cachedRxData.append(data)
        
        // Send data to delegate
        delegate?.onUartRx(data: cachedRxData)

        //DLog("cachedRxData: \(cachedRxData.count)")

        cachedRxDataSemaphore.signal()
    }
    
    func clearRxCache() {
        cachedRxData.removeAll()
    }
    
    func removeRxCacheFirst(n: Int) {
        if n <= cachedRxData.count {
            cachedRxData.removeFirst(n)
        }
        else {
            clearRxCache()
        }
    }

    func flushRxCache() {
        if cachedRxData.count > 0 {
            cachedRxDataSemaphore.wait()
            delegate?.onUartRx(data: cachedRxData)
            cachedRxDataSemaphore.signal()
        }
    }
}
