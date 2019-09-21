//
//  UartDataManager.swift
//  Calibration
//
//  Created by Antonio García on 20/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

protocol UartDataManagerDelegate: class {
    func onUartRx(data: Data, peripheralIdentifier: UUID)           // data contents depends on the isRxCacheEnabled flag
}

// Basic Uart Management. Use it to cache all data received and help parsing it
class UartDataManager {

    // Params
    var isEnabled: Bool {
        didSet {
            if isEnabled != oldValue {
                registerNotifications(enabled: isEnabled)
            }
        }
    }
    var isRxCacheEnabled: Bool {   // If cache is enabled, onUartRx sends the cachedData. Cache can be cleared using removeRxCacheFirst or clearRxCache. If not enabled, onUartRx sends only the latest data received
        didSet {
            if !isRxCacheEnabled {
                DLog("Clearing all rx caches")
                rxDatas.removeAll()
            }
        }
    }
    weak var delegate: UartDataManagerDelegate?

    // Data
    fileprivate var rxDatas = [UUID: Data]()
    fileprivate var rxDataSemaphore = DispatchSemaphore(value: 1)

    init(delegate: UartDataManagerDelegate?, isRxCacheEnabled: Bool) {
        self.delegate = delegate
        self.isRxCacheEnabled = isRxCacheEnabled
        
        isEnabled = true
    }

    deinit {
        isEnabled = false
    }

    // MARK: - BLE Notifications
    private weak var didConnectToPeripheralObserver: NSObjectProtocol?
    private weak var didDisconnectFromPeripheralObserver: NSObjectProtocol?

    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            didConnectToPeripheralObserver = notificationCenter.addObserver(forName: .didConnectToPeripheral, object: nil, queue: .main, using: {[weak self] notification in self?.didConnectToPeripheral(notification: notification)})
            didDisconnectFromPeripheralObserver = notificationCenter.addObserver(forName: .didDisconnectFromPeripheral, object: nil, queue: .main, using: {[weak self] notification in self?.didDisconnectFromPeripheral(notification: notification)})

        } else {
            if let didConnectToPeripheralObserver = didConnectToPeripheralObserver {notificationCenter.removeObserver(didConnectToPeripheralObserver)}
            if let didDisconnectFromPeripheralObserver = didDisconnectFromPeripheralObserver {notificationCenter.removeObserver(didDisconnectFromPeripheralObserver)}
        }
    }

    private func didConnectToPeripheral(notification: Notification) {
        guard let identifier = notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID else { return }

        clearRxCache(peripheralIdentifier: identifier)
    }

    private func didDisconnectFromPeripheral(notification: Notification) {
        guard let identifier = notification.userInfo?[BleManager.NotificationUserInfoKey.uuid.rawValue] as? UUID else { return }

        // Clean data on disconnect
        rxDatas[identifier] = nil

        rxDataSemaphore.signal()        // Force signal if was waiting
    }

    // MARK: - Send data
    func send(blePeripheral: BlePeripheral, data: Data?, completion: ((Error?) -> Void)? = nil) {
        blePeripheral.uartSend(data: data, completion: completion)
    }

    
    // MARK: - Received data
    func rxDataReceived(data: Data?, peripheralIdentifier identifier: UUID, error: Error?) {
        guard error == nil else { DLog("rxDataReceived error: \(error!)"); return }
        guard let data = data else { return }

        // Pre-create rxData entry if needed
        if isRxCacheEnabled && rxDatas[identifier] == nil {
            rxDatas[identifier] = Data()
        }

        if isRxCacheEnabled {
            rxDataSemaphore.wait()            // don't append more data, till the delegate has finished processing it
            rxDatas[identifier]!.append(data)

            // Send data to delegate
            delegate?.onUartRx(data: rxDatas[identifier]!, peripheralIdentifier: identifier)

            //DLog("cachedRxData: \(cachedRxData.count)")
            rxDataSemaphore.signal()
        } else {
            delegate?.onUartRx(data: data, peripheralIdentifier: identifier)
        }
    }

    func clearRxCache(peripheralIdentifier identifier: UUID) {
        guard rxDatas[identifier] != nil else { return }

        rxDatas[identifier]!.removeAll()
    }

    func removeRxCacheFirst(n: Int, peripheralIdentifier identifier: UUID) {
        // Note: this is usually called from onUartRx delegates, so don't use rxDataSemaphore because it is already being used by the onUartRX caller
        guard let rxData = rxDatas[identifier] else { return }

        //DLog("remove \(n) items")
        //DLog("pre remove: \(hexDescription(data: rxData))")

        if n < rxData.count {
            rxDatas[identifier]!.removeFirst(n)
        } else {
            clearRxCache(peripheralIdentifier: identifier)
        }

        //DLog("post remove: \(hexDescription(data: rxDatas[identifier]!))")
    }

    func flushRxCache(peripheralIdentifier identifier: UUID) {
        guard let rxData = rxDatas[identifier] else { return }

        if rxData.count > 0 {
            rxDataSemaphore.wait()
            delegate?.onUartRx(data: rxData, peripheralIdentifier: identifier)
            rxDataSemaphore.signal()
        }
    }
}
