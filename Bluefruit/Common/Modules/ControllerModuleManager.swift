//
//  ControllerModuleManager.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation
import CoreLocation
import MSWeakTimer

// TODO: add support for OSX
#if os(OSX)
#else
    import CoreMotion
#endif

protocol ControllerModuleManagerDelegate: class {
    func onControllerUartIsReady(error: Error?)
    func onUarRX()
}

class ControllerModuleManager: NSObject {

    enum ControllerType: Int {
        case attitude = 0
        case accelerometer
        case gyroscope
        case magnetometer
        case location
    }
    static let numSensors = 5

    static private let prefixes = ["!Q", "!A", "!G", "!M", "!L"]     // same order that ControllerType

    // Params
    weak var delegate: ControllerModuleManagerDelegate?
    var isUartRxCacheEnabled = false {
        didSet {
            if isUartRxCacheEnabled {
                uartManager.delegate = self
            } else {
                uartManager.delegate = nil
            }
        }
    }

    // Data
    fileprivate var isSensorEnabled = [Bool](repeating: false, count: ControllerModuleManager.numSensors)

    #if os(OSX)
    #else
    private let coreMotionManager = CMMotionManager()
    #endif
    private let locationManager = CLLocationManager()
    fileprivate var lastKnownLocation: CLLocation?

    fileprivate var blePeripheral: BlePeripheral
    private var pollTimer: MSWeakTimer?
    private var timerHandler: (() -> Void)?

    fileprivate let uartManager: UartDataManager// = UartDataManager(delegate: self)
    fileprivate var textCachedBuffer: String = ""

    private var pollInterval: TimeInterval = 1        // in seconds

    init(blePeripheral: BlePeripheral, delegate: ControllerModuleManagerDelegate) {
        self.blePeripheral = blePeripheral
        self.delegate = delegate
        uartManager = UartDataManager(delegate: nil)
        super.init()

        // Setup Location Manager
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.delegate = self
    }

    deinit {
        locationManager.delegate = nil
        // Disable everthing
        for i in 0..<ControllerModuleManager.numSensors {
            setSensorEnabled(false, index: i)
        }
    }

    // MARK: - Start / Stop
    func start(pollInterval: TimeInterval, handler:(() -> Void)?) {
        self.pollInterval = pollInterval
        self.timerHandler = handler

        // Enable Uart
        blePeripheral.uartEnable(uartRxHandler: uartManager.rxDataReceived) { [weak self] error in
            guard let context = self else {  return }

            context.delegate?.onControllerUartIsReady(error: error)

            guard error == nil else { return }

            // Done
            context.startUpdatingData()
        }
    }

    func stop() {
        stopUpdatingData()
    }

    // MARK: - Send Data
    func sendCrcData(_ data: Data) {
        var crcData = data
        crcData.appendCrc()

        uartManager.send(blePeripheral: blePeripheral, data: crcData)
    }

    // MARK: - Uart Data Cache
    func uartTextBuffer() -> String {
        return textCachedBuffer
    }
    
    func uartRxCacheReset() {
        uartManager.clearRxCache(peripheralIdentifier: blePeripheral.identifier)
        textCachedBuffer.removeAll()
    }

    // MARK: -
    private func startUpdatingData() {
        pollTimer = MSWeakTimer.scheduledTimer(withTimeInterval: pollInterval, target: self, selector: #selector(updateSensors), userInfo: nil, repeats: true, dispatchQueue: DispatchQueue.main)
    }

    private func stopUpdatingData() {
        timerHandler = nil
        pollTimer?.invalidate()
        pollTimer = nil
    }

    @objc func updateSensors() {
        timerHandler?()

        for i in 0..<ControllerModuleManager.numSensors {
            if isSensorEnabled(index: i) {
                if let sensorData = getSensorData(index: i) {

                    var data = Data()
                    let prefixData = ControllerModuleManager.prefixes[i].data(using: .utf8)!
                    data.append(prefixData)

                    for value in sensorData {
                        var floatValue = Float(value)
                        data.append(UnsafeBufferPointer(start: &floatValue, count: 1))
                    }

                    sendCrcData(data)
                }
            }
        }
    }

    func isSensorEnabled(index: Int) -> Bool {
        return isSensorEnabled[index]
    }

    func getSensorData(index: Int) -> [Double]? {
        guard isSensorEnabled(index: index) else {
            return nil
        }

        switch ControllerType(rawValue: index)! {
        case .attitude:
            if let attitude = coreMotionManager.deviceMotion?.attitude {
                return [attitude.quaternion.x, attitude.quaternion.y, attitude.quaternion.z, attitude.quaternion.w]
            }
        case .accelerometer:
            if let acceleration = coreMotionManager.accelerometerData?.acceleration {
                return [acceleration.x, acceleration.y, acceleration.z]
            }
        case .gyroscope:
            if let rotation = coreMotionManager.gyroData?.rotationRate {
                return [rotation.x, rotation.y, rotation.z]
            }
        case .magnetometer:
            if let magneticField = coreMotionManager.magnetometerData?.magneticField {
                return [magneticField.x, magneticField.y, magneticField.z]
            }
        case .location:
            if let location = lastKnownLocation {
                return [location.coordinate.latitude, location.coordinate.longitude, location.altitude]
            }
        }

        return nil
    }

    @discardableResult func setSensorEnabled(_ enabled: Bool, index: Int) -> String? {
        isSensorEnabled[index] = enabled

        var errorString: String?
        switch ControllerType(rawValue: index)! {
        case .attitude:
            if enabled {
                coreMotionManager.startDeviceMotionUpdates()
            } else {
                coreMotionManager.stopDeviceMotionUpdates()
            }

        case .accelerometer:
            if enabled {
                coreMotionManager.startAccelerometerUpdates()
            } else {
                coreMotionManager.stopAccelerometerUpdates()
            }
        case .gyroscope:
            if enabled {
                coreMotionManager.startGyroUpdates()
            } else {
                coreMotionManager.stopGyroUpdates()
            }

        case .magnetometer:
            if enabled {
                coreMotionManager.startMagnetometerUpdates()
            } else {
                coreMotionManager.stopMagnetometerUpdates()
            }

        case .location:
            if enabled {
                if CLLocationManager.locationServicesEnabled() {
                    let authorizationStatus = CLLocationManager.authorizationStatus()
                    switch authorizationStatus {
                    case .notDetermined:
                        locationManager.requestWhenInUseAuthorization()
                    case .denied:
                        errorString = LocalizationManager.sharedInstance.localizedString("controller_sensor_location_denied")
                    case .restricted:
                        errorString = LocalizationManager.sharedInstance.localizedString("controller_sensor_location_restricted")
                    default:
                        locationManager.startUpdatingLocation()
                    }
                } else {      // Location services disabled
                    DLog("Location services disabled")
                    errorString = LocalizationManager.sharedInstance.localizedString("controller_sensor_location_disabled")
                }
            } else {
                locationManager.stopUpdatingLocation()
            }

        }

        return errorString
    }
}

 // MARK: - CLLocationManagerDelegate
extension ControllerModuleManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastKnownLocation = locations.last
    }
}

// MARK: - UartDataManagerDelegate
extension ControllerModuleManager: UartDataManagerDelegate {
    func onUartRx(data: Data, peripheralIdentifier: UUID) {
        if let dataString = stringFromData(data, useHexMode: false) {
            //DLog("rx: \(dataString)")
            textCachedBuffer.append(dataString)
            DispatchQueue.main.async { [unowned self] in
                self.delegate?.onUarRX()
            }
        }
        uartManager.removeRxCacheFirst(n: data.count, peripheralIdentifier: peripheralIdentifier)
    }
}
