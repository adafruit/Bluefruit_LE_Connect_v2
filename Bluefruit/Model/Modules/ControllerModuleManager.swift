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

protocol ControllerModuleManagerDelegate: AnyObject {
    func onControllerUartIsReady(error: Error?)
    func onUarRX()
}

class ControllerModuleManager: NSObject {
    
    enum ControllerType: Int, CaseIterable {
        case altitude = 0
        case accelerometer
        case gyroscope
        case magnetometer
        case location
        
        var prefix: String {
            switch self {
            case .altitude:
                return "!Q"
            case .accelerometer:
                return "!A"
            case .gyroscope:
                return "!G"
            case .magnetometer:
                return "!M"
            case .location:
                return "!L"
            }
        }
    }
    
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
    private var isSensorEnabled = [Bool](repeating: false, count: ControllerType.allCases.count)

    #if os(OSX)
    #else
    private let coreMotionManager = CMMotionManager()
    #endif
    private let locationManager = CLLocationManager()
    private var lastKnownLocation: CLLocation?

    private var blePeripheral: BlePeripheral
    private var pollTimer: MSWeakTimer?
    private var timerHandler: (() -> Void)?

    private let uartManager: UartDataManager
    private var textCachedBuffer: String = ""

    private var pollInterval: TimeInterval = 1        // in seconds

    init(blePeripheral: BlePeripheral, delegate: ControllerModuleManagerDelegate) {
        self.blePeripheral = blePeripheral
        self.delegate = delegate
        uartManager = UartDataManager(delegate: nil, isRxCacheEnabled: false)
        super.init()

        // Setup Location Manager
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.delegate = self
    }

    deinit {
        locationManager.delegate = nil
        
        // Disable everything
        ControllerType.allCases.forEach { controllerType in
            setSensorEnabled(false, controllerType: controllerType)
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
        pollTimer = MSWeakTimer.scheduledTimer(withTimeInterval: pollInterval, target: self, selector: #selector(updateSensors), userInfo: nil, repeats: true, dispatchQueue: .main)
    }

    private func stopUpdatingData() {
        timerHandler = nil
        pollTimer?.invalidate()
        pollTimer = nil
    }

    @objc private func updateSensors() {
        timerHandler?()

        ControllerType.allCases.forEach { controllerType in
            if isSensorEnabled(controllerType: controllerType) {
                if let sensorData = getSensorData(controllerType: controllerType) {

                    var data = Data()
                    let prefixData = controllerType.prefix.data(using: .utf8)!
                    data.append(prefixData)

                    for value in sensorData {
                        var floatValue = Float(value)
                        withUnsafePointer(to: &floatValue) { data.append(UnsafeBufferPointer(start: $0, count: 1)) }
                    }

                    sendCrcData(data)
                }
            }
        }
    }

    func isSensorEnabled(controllerType: ControllerType) -> Bool {
        return isSensorEnabled[controllerType.rawValue]
    }

    func getSensorData(controllerType: ControllerType) -> [Double]? {
        guard isSensorEnabled(controllerType: controllerType) else {
            return nil
        }

        switch controllerType {
        case .altitude:
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

    @discardableResult func setSensorEnabled(_ enabled: Bool, controllerType: ControllerType) -> String? {
        isSensorEnabled[controllerType.rawValue] = enabled

        var errorString: String?
        switch controllerType {
        case .altitude:
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
                        errorString = LocalizationManager.shared.localizedString("controller_sensor_location_denied")
                    case .restricted:
                        errorString = LocalizationManager.shared.localizedString("controller_sensor_location_restricted")
                    default:
                        locationManager.startUpdatingLocation()
                    }
                } else {      // Location services disabled
                    DLog("Location services disabled")
                    errorString = LocalizationManager.shared.localizedString("controller_sensor_location_disabled")
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
            DispatchQueue.main.async {
                self.delegate?.onUarRX()
            }
        }
        uartManager.removeRxCacheFirst(n: data.count, peripheralIdentifier: peripheralIdentifier)
    }
}
