//
//  PinIOModuleManager.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 16/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

// http://www.firmata.org/wiki/V2.3ProtocolDetails#Capability_Query
// TODO: update to the lastest specification 2.5.1: https://github.com/firmata/protocol/blob/master/protocol.md

import Foundation
import MSWeakTimer

protocol PinIOModuleManagerDelegate: class {
    func onPinIODidEndPinQuery(isDefaultConfigurationAssumed: Bool)
    func onPinIODidReceivePinState()
}

class PinIOModuleManager: NSObject {
    // Config
    private let CAPABILITY_QUERY_TIMEOUT = 5.0      // in seconds

    // Constants
    private let SYSEX_START: UInt8 = 0xF0
    private let SYSEX_END: UInt8 = 0xF7

    private let DEFAULT_PINS_COUNT = 20
    private let FIRST_DIGITAL_PIN = 3
    private let LAST_DIGITAL_PIN = 8
    private let FIRST_ANALOG_PIN = 14
    private let LAST_ANALOG_PIN = 19

    // Types
    enum UartStatus {
        case inputOutput           // Default mode (sending and receiving pin data)
        case queryCapabilities
        case queryAnalogMapping
    }

    class PinData {
        enum Mode: UInt8 {
            case unknown = 255
            case input = 0          // Don't chage the values (these are the bytes defined by firmata spec)
            case output = 1

            case analog = 2
            case pwm = 3
            case servo = 4

            var description: String {
                switch self {
                case .input: return "Input"
                case .output: return "Output"
                case .analog:  return "Analog"
                case .pwm: return "PWM"
                case .servo: return "Servo"
                default: return "Unkwnown"
                }
            }
        }

        enum DigitalValue: Int {
            case low = 0
            case high = 1

            var description: String {
                switch self {
                case .low: return "Low"
                case .high: return "High"
                }
            }
        }

        var digitalPinId: Int = -1
        var analogPinId: Int = -1

        var isDigital: Bool
        var isAnalog: Bool
        var isPWM: Bool

        var mode = Mode.input
        var digitalValue =  DigitalValue.low
        var analogValue: Int = 0

        init(digitalPinId: Int, isDigital: Bool, isAnalog: Bool, isPWM: Bool) {
            self.digitalPinId = digitalPinId
            self.isDigital = isDigital
            self.isAnalog = isAnalog
            self.isPWM = isPWM
        }
    }

    // Data
    fileprivate var uartStatus = UartStatus.inputOutput
    private var queryCapabilitiesTimer: MSWeakTimer?
    fileprivate var uartManager: UartDataManager!
    private var blePeripheral: BlePeripheral

    var pins = [PinData]()

    weak var delegate: PinIOModuleManagerDelegate?

    var digitalPinCount: Int {
        return pins.filter {$0.isDigital}.count
    }

    var analogPinCount: Int {
        return pins.filter {$0.isAnalog}.count
    }

    init(blePeripheral: BlePeripheral, delegate: PinIOModuleManagerDelegate) {
        self.blePeripheral = blePeripheral
        self.delegate = delegate
        super.init()

        uartManager = UartDataManager(delegate: self)
        uartManager.isRxCacheEnabled = false
    }

    deinit {
        cancelQueryCapabilitiesTimer()
    }

    func isQueryingCapabilities() -> Bool {
        return uartStatus != UartStatus.inputOutput
    }

    func start(uartReadyCompletion:@escaping ((Error?) -> (Void))) {
        DLog("pinio start")

        // Enable Uart
        blePeripheral.uartEnable(uartRxHandler: uartManager.rxDataReceived) { error in
            uartReadyCompletion(error)
        }
    }

    func stop() {
        DLog("pinio stop")

        // Cancel pending queries
        cancelQueryCapabilitiesTimer()
    }

    // MARK: - Query Capabilities
    func reset() {
        uartStatus = .inputOutput
        pins = []

        // Reset Firmata
        let bytes: [UInt8] = [0xff]
        let data = Data(bytes: bytes)
        uartManager.send(blePeripheral: blePeripheral, data: data)
    }

    private var queryCapabilitiesDataBuffer = [UInt8]()
    func queryCapabilities() {
        DLog("queryCapabilities")

        // Set status
        pins = []
        self.uartStatus = .queryCapabilities
        self.queryCapabilitiesDataBuffer.removeAll()

        // Query Capabilities
        let bytes: [UInt8] = [SYSEX_START, 0x6B, SYSEX_END]
        let data = Data(bytes: bytes)
        uartManager.send(blePeripheral: blePeripheral, data: data)

        queryCapabilitiesTimer = MSWeakTimer.scheduledTimer(withTimeInterval: CAPABILITY_QUERY_TIMEOUT, target: self, selector: #selector(cancelQueryCapabilities), userInfo: nil, repeats: false, dispatchQueue: DispatchQueue.main)
    }

    fileprivate func receivedQueryCapabilities(data: Data) {
        // Read received packet
        var dataBytes = [UInt8](repeating: 0, count: data.count)
        data.copyBytes(to: &dataBytes, count: data.count)

        for byte in dataBytes {
            queryCapabilitiesDataBuffer.append(byte)
            if byte == SYSEX_END {
                DLog("Finished receiving Capabilities")
                queryAnalogMapping()
                break
            }
        }
    }

    fileprivate func cancelQueryCapabilitiesTimer() {
        queryCapabilitiesTimer?.invalidate()
        queryCapabilitiesTimer = nil
    }

    // MARK: - Query AnalogMapping
    private var queryAnalogMappingDataBuffer = [UInt8]()

    private func queryAnalogMapping() {
        DLog("queryAnalogMapping")

        // Set status
        self.uartStatus = .queryAnalogMapping
        self.queryAnalogMappingDataBuffer.removeAll()

        // Query Analog Mapping
        let bytes: [UInt8] = [self.SYSEX_START, 0x69, self.SYSEX_END]
        let data = Data(bytes: bytes)
        uartManager.send(blePeripheral: blePeripheral, data: data)
    }

    fileprivate func receivedAnalogMapping(data: Data) {
        cancelQueryCapabilitiesTimer()

        // Read received packet
        var dataBytes = [UInt8](repeating: 0, count: data.count)
        data.copyBytes(to: &dataBytes, count: data.count)

        for byte in dataBytes {
            queryAnalogMappingDataBuffer.append(byte)
            if byte == SYSEX_END {
                DLog("Finished receiving Analog Mapping")
                endPinQuery(abort: false)
                break
            }
        }
    }

    @objc func cancelQueryCapabilities() {
        DLog("timeout: cancelQueryCapabilities")
        endPinQuery(abort: true)
    }

    // MARK: - Process Capabilities
    func endPinQuery(abort abortQuery: Bool) {
        cancelQueryCapabilitiesTimer()
        uartStatus = .inputOutput

        var capabilitiesParsed = false
        var mappingDataParsed = false
        if !abortQuery && queryCapabilitiesDataBuffer.count > 0 && queryAnalogMappingDataBuffer.count > 0 {
            capabilitiesParsed = parseCapabilities(queryCapabilitiesDataBuffer)
            mappingDataParsed = parseAnalogMappingData(queryAnalogMappingDataBuffer)
        }

        let isDefaultConfigurationAssumed =  abortQuery || !capabilitiesParsed || !mappingDataParsed
        if isDefaultConfigurationAssumed {
            initializeDefaultPins()
        }
        enableReadReports()

        // Clean received data
        queryCapabilitiesDataBuffer.removeAll()
        queryAnalogMappingDataBuffer.removeAll()

        // Refresh
        delegate?.onPinIODidEndPinQuery(isDefaultConfigurationAssumed: isDefaultConfigurationAssumed)
    }

    private func parseCapabilities(_ cababilitiesData: [UInt8]) -> Bool {
        let endIndex = cababilitiesData.index(of: SYSEX_END)
        guard cababilitiesData.count > 2 && cababilitiesData[0] == SYSEX_START && cababilitiesData[1] == 0x6C && endIndex != nil else {
            DLog("invalid capabilities received")
            return false
        }

        // Separate pin data
        var pinsBytes = [[UInt8]]()
        var currentPin = [UInt8]()
        for i in 2..<endIndex! {         // Skip 2 header bytes and end byte
            let dataByte = cababilitiesData[i]
            if dataByte != 0x7f {
                currentPin.append(dataByte)
            } else {  // Finished current pin
                pinsBytes.append(currentPin)
                currentPin = []
            }
        }

        // Extract pin info
        self.pins = []
        var pinNumber = 0
        for pinBytes in pinsBytes {
            var isInput = false, isOutput = false, isAnalog = false, isPWM = false

            if pinBytes.count > 0 {     // if is available
                var i = 0
                while i<pinBytes.count {
                    let byte = pinBytes[i]
                    switch byte {
                    case 0x00:
                        isInput = true
                        i += 1      // skip resolution byte
                    case 0x01:
                        isOutput = true
                        i += 1      // skip resolution byte
                    case 0x02:
                        isAnalog = true
                        i += 1      // skip resolution byte
                    case 0x03:
                        isPWM = true
                        i += 1      // skip resolution byte
                    case 0x04:
                        // Servo
                        i += 1      // skip resolution byte
                    case 0x06:
                        // I2C
                        i += 1      // skip resolution byte
                    case 0x0b:
                        // INPUT_PULLUP
                        isInput = true
                        i += 1      // skip resolution byte
                    default:
                        i += 1      // skip resolution byte for unknown commands
                    }
                    i += 1
                }

                let pinData = PinData(digitalPinId: pinNumber, isDigital: isInput && isOutput, isAnalog: isAnalog, isPWM: isPWM)
                DLog("pin id: \(pinNumber) digital: \(pinData.isDigital) analog: \(pinData.isAnalog)")
                self.pins.append(pinData)
            }

            pinNumber += 1
        }

        return true
    }

    private func parseAnalogMappingData(_ analogData: [UInt8]) -> Bool {
        let endIndex = analogData.index(of: SYSEX_END)
        guard analogData.count > 2 && analogData[0] == SYSEX_START && analogData[1] == 0x6A && endIndex != nil else {
            DLog("invalid analog mapping received")
            return false
        }

        var pinNumber = 0
        for i in 2..<endIndex! {         // Skip 2 header bytes and end byte
            let dataByte = analogData[i]
            if dataByte != 0x7f {
                if let indexOfPinNumber = indexOfPinWithDigitalId(pinNumber) {
                    pins[indexOfPinNumber].analogPinId = Int(dataByte)
                    DLog("pin id: \(pinNumber) analog id: \(Int(dataByte))")
                } else {
                    DLog("warning: trying to set analog id: \(Int(dataByte)) for pin id: \(pinNumber)")
                }
            }
            pinNumber += 1
        }

        return true
    }

    private func indexOfPinWithDigitalId(_ digitalPinId: Int) -> Int? {
        return pins.index { (pin) -> Bool in
            pin.digitalPinId == digitalPinId
        }
    }

    private func indexOfPinWithAnalogId(_ analogPinId: Int) -> Int? {
        return pins.index { (pin) -> Bool in
            pin.analogPinId == analogPinId
        }
    }

    // MARK: - Pin Management
    private func initializeDefaultPins() {
        pins.removeAll()

        for i in 0..<DEFAULT_PINS_COUNT {
            var pin: PinData!
            if i == 3 || i == 5 || i == 6 {     // PWM pins
                pin = PinData(digitalPinId: i, isDigital: true, isAnalog: false, isPWM: false)
            } else if i >= FIRST_DIGITAL_PIN && i <= LAST_DIGITAL_PIN {    // Digital pin
                pin = PinData(digitalPinId: i, isDigital: true, isAnalog: false, isPWM: false)
            } else if i >= FIRST_ANALOG_PIN && i <= LAST_ANALOG_PIN {     // Analog pin
                pin = PinData(digitalPinId: i, isDigital: true, isAnalog: true, isPWM: false)
                pin.analogPinId = i-FIRST_ANALOG_PIN
            }

            if let pin = pin {
                pins.append(pin)
            }
        }
    }

    private func enableReadReports() {

        //Enable Read Reports by port
        let ports: [UInt8] = [0, 1, 2]
        for port in ports {
            let data0: UInt8 = 0xD0 + port        // start port 0 digital reporting (0xD0 + port#)
            let data1: UInt8 = 1                  // enable
            let bytes: [UInt8] = [data0, data1]
            let data = Data(bytes: bytes)
            uartManager.send(blePeripheral: blePeripheral, data: data)
        }

        //Set all pin modes active
        for pin in pins {
            // Write pin mode
            setControlMode(pin: pin, mode: pin.mode)
        }
    }

    func setControlMode(pin: PinData, mode: PinData.Mode) {
        let previousMode = pin.mode

        // Store
        pin.mode = mode
        pin.digitalValue = .low     // Reset dialog value when chaning mode
        pin.analogValue = 0         // Reset analog value when chaging mode

        //DLog("pin \(pin.digitalPinId): mode: \(pin.mode.rawValue)")

        // Write pin mode
        let bytes: [UInt8] = [0xf4, UInt8(pin.digitalPinId), mode.rawValue]
        let data = Data(bytes: bytes)
        uartManager.send(blePeripheral: blePeripheral, data: data)

        // Update reporting for Analog pins
        if mode == .analog {
            setAnalogValueReporting(pin: pin, enabled: true)
        } else if previousMode == .analog {
            setAnalogValueReporting(pin: pin, enabled: false)
        }
    }

    func setAnalogValueReporting(pin: PinData, enabled: Bool) {
        // Write pin mode
        let bytes: [UInt8] = [0xC0 + UInt8(pin.analogPinId), UInt8(enabled ?1:0)]
        let data = Data(bytes: bytes)
        uartManager.send(blePeripheral: blePeripheral, data: data)
    }

    func setDigitalValue(pin: PinData, value: PinData.DigitalValue) {
        // Store
        pin.digitalValue = value
        DLog("setDigitalValue: \(value) for pin id: \(pin.digitalPinId)")

        // Write value
        let port = UInt8(pin.digitalPinId / 8)
        let data0 = 0x90 + port

        let offset = 8 * Int(port)
        var state: Int = 0
        for i in 0...7 {
            if let pinIndex = indexOfPinWithDigitalId(offset + i) {
                let pinValue = pins[pinIndex].digitalValue.rawValue & 0x1
                let pinMask = pinValue << i
                state |= pinMask
            }
        }

        let data1 = UInt8(state & 0x7f)         // only 7 bottom bits
        let data2 = UInt8(state >> 7)           // top bit in second byte

        let bytes: [UInt8] = [data0, data1, data2]
        let data = Data(bytes: bytes)
        uartManager.send(blePeripheral: blePeripheral, data: data)
    }

    private var lastSentAnalogValueTime: TimeInterval = 0
    func setPMWValue(pin: PinData, value: Int) -> Bool {

        // Limit the amount of messages sent over Uart
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastSentAnalogValueTime >= 0.05 else {
            DLog("Won't send: Too many slider messages")
            return false
        }
        lastSentAnalogValueTime = currentTime
        
        // Store
        pin.analogValue = value
        
        // Send
        var bytes: [UInt8]
        if pin.digitalPinId > 15 {
            // Extended Analog
            let data0 = UInt8(pin.digitalPinId)
            let data1 = UInt8(value & 0x7f)                 // only 7 bottom bits
            let data2 = UInt8(value >> 7)                   // top bit in second byte
            
            bytes = [SYSEX_START, 0x6f, data0, data1, data2, SYSEX_END]
        }
        else {
            let data0 = 0xe0 + UInt8(pin.digitalPinId)
            let data1 = UInt8(value & 0x7f)                 // only 7 bottom bits
            let data2 = UInt8(value >> 7)                   // top bit in second byte
            
            bytes = [data0, data1, data2]
        }
        
        let data = Data(bytes: bytes)
        uartManager.send(blePeripheral: blePeripheral, data: data)

        return true
    }

    private var receivedPinStateDataBuffer = [UInt8]()

    fileprivate func receivedPinState(data: Data) {

        // Append received bytes to buffer
        var receivedDataBytes = [UInt8](repeating: 0, count: data.count)
        data.copyBytes(to: &receivedDataBytes, count: data.count)
        for byte in receivedDataBytes {
            receivedPinStateDataBuffer.append(byte)
        }

        // Check if we received a pin state response
        let endIndex = receivedPinStateDataBuffer.index(of: SYSEX_END)
        if receivedPinStateDataBuffer.count >= 5 && receivedPinStateDataBuffer[0] == SYSEX_START && receivedPinStateDataBuffer[1] == 0x6e && endIndex != nil {
            /* pin state response
            * -------------------------------
            * 0  START_SYSEX (0xF0) (MIDI System Exclusive)
            * 1  pin state response (0x6E)
            * 2  pin (0 to 127)
            * 3  pin mode (the currently configured mode)
            * 4  pin state, bits 0-6
            * 5  (optional) pin state, bits 7-13
            * 6  (optional) pin state, bits 14-20
            ...  additional optional bytes, as many as needed
            * N  END_SYSEX (0xF7)
            */

            let pinDigitalId = Int(receivedPinStateDataBuffer[2])
            let pinMode = PinData.Mode(rawValue: receivedPinStateDataBuffer[3])
            let pinState = Int(receivedPinStateDataBuffer[4])

            if let index = indexOfPinWithDigitalId(pinDigitalId), let pinMode = pinMode {
                let pin = pins[index]
                pin.mode = pinMode
                if pinMode == .analog || pinMode == .pwm || pinMode == .servo {
                    if receivedPinStateDataBuffer.count >= 6 {
                        let analogValue = pinState + (Int(receivedPinStateDataBuffer[5])<<7)
                        pin.analogValue = analogValue
                    } else {
                        DLog("Warning: received pinstate for analog pin without analogValue")
                    }
                } else {
                    if let digitalValue = PinData.DigitalValue(rawValue: pinState) {
                         pin.digitalValue = digitalValue
                    } else {
                        DLog("Warning: received pinstate with unknown digital value. Valid (0,1). Received: \(pinState)")
                    }
                }
            } else {
                DLog("Warning: received pinstate for unknown digital pin id: \(pinDigitalId)")
            }

            // Remove from the buffer the bytes parsed
            if let endIndex = endIndex {
                receivedPinStateDataBuffer.removeFirst(endIndex)
            }
        } else {
            // Each pin state message is 3 bytes long
            var isDigitalReportingMessage = (receivedPinStateDataBuffer[0] >= 0x90) && (receivedPinStateDataBuffer[0] <= 0x9F)
            var isAnalogReportingMessage = (receivedPinStateDataBuffer[0] >= 0xE0) && (receivedPinStateDataBuffer[0] <= 0xEF)

            DLog("receivedPinStateDataBuffer size: \(receivedPinStateDataBuffer.count)")

            while receivedPinStateDataBuffer.count >= 3 && (isDigitalReportingMessage || isAnalogReportingMessage)        // Check that current message length is at least 3 bytes
            {
                if isDigitalReportingMessage {             // Digital Reporting (per port)
                    /* two byte digital data format, second nibble of byte 0 gives the port number (e.g. 0x92 is the third port, port 2)
                    * 0  digital data, 0x90-0x9F, (MIDI NoteOn, but different data format)
                    * 1  digital pins 0-6 bitmask
                    * 2  digital pin 7 bitmask 
                    */

                    let port = Int(receivedPinStateDataBuffer[0]) - 0x90
                    var pinStates = Int(receivedPinStateDataBuffer[1])
                    pinStates |= Int(receivedPinStateDataBuffer[2]) << 7           // PORT 0: use LSB of third byte for pin7, PORT 1: pins 14 & 15
                    updatePinsForReceivedStates(pinStates, port: port)
                } else if isAnalogReportingMessage {       // Analog Reporting (per pin)

                    /* analog 14-bit data format
                    * 0  analog pin, 0xE0-0xEF, (MIDI Pitch Wheel)
                    * 1  analog least significant 7 bits
                    * 2  analog most significant 7 bits
                    */

                    let analogPinId = Int(receivedPinStateDataBuffer[0]) - 0xE0
                    let value = Int(receivedPinStateDataBuffer[1]) + (Int(receivedPinStateDataBuffer[2])<<7)

                    if let index = indexOfPinWithAnalogId(analogPinId) {
                        let pin = pins[index]
                        pin.analogValue = value
                    } else {
                        DLog("Warning: received pinstate for unknown analog pin id: \(index)")
                    }
                }

                // Remove from the buffer the bytes parsed
                receivedPinStateDataBuffer.removeFirst(3)

                // Setup vars for next message
                if receivedPinStateDataBuffer.count >= 3 {
                    isDigitalReportingMessage = (receivedPinStateDataBuffer[0] >= 0x90) && (receivedPinStateDataBuffer[0] <= 0x9F)
                    isAnalogReportingMessage = (receivedPinStateDataBuffer[0] >= 0xE0) && (receivedPinStateDataBuffer[0] <= 0xEF)
                } else {
                    isDigitalReportingMessage = false
                    isAnalogReportingMessage = false
                }
            }

        }

        // Refresh UI
        delegate?.onPinIODidReceivePinState()
    }

    private func updatePinsForReceivedStates(_ pinStates: Int, port: Int) {
        let offset = 8 * port

        // Iterate through all pins
        for i in 0...7 {
            let mask = 1 << i
            let state = (pinStates & mask) >> i

            let digitalId = offset + i

            if let index = indexOfPinWithDigitalId(digitalId), let digitalValue = PinData.DigitalValue(rawValue: state) {
                let pin = pins[index]
                pin.digitalValue = digitalValue
                DLog("update pinid: \(digitalId) digitalValue: \(digitalValue)")
            }
        }
    }
}

// MARK: - UartDataManagerDelegate
extension PinIOModuleManager: UartDataManagerDelegate {
    func onUartRx(data: Data, peripheralIdentifier: UUID) {
        DLog("uart rx read (hex): \(hexDescription(data: data))")

        switch uartStatus {
        case .queryCapabilities:
            receivedQueryCapabilities(data: data)
        case .queryAnalogMapping:
            receivedAnalogMapping(data: data)
        default:
            receivedPinState(data: data)
        }
    }
}
