//
//  GyroscopeViewController.swift
//  Calibration
//
//  Created by Antonio on 11/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit
import SceneKit

class GyroscopeViewController: CalibrationUartSamplerViewController {

    // Config
    static let kReadingsMaxDifferenceToBeStable: Float = 60
    static let kNumReadingsToCheckForStable = 50

    // Debug
    fileprivate static let kSimulateReads = Config.isDebugEnabled && false //false
    fileprivate static let kSimulateReadsFileName = "gyro_test_1"
    fileprivate static let kSimulateReadsInBulk = kSimulateReads && true
    fileprivate var lines: [String]!
    fileprivate var currentLine = 0

    // PageViewController
    fileprivate static let kPageControllerIds = ["GyroscopeProgressViewController", "GyroscopePageDataViewController"]

    // 3D Scene
    var axisNode: SCNNode!
    var currentOrientation = Vector4.zero

    // Data
    fileprivate var calibration = Calibration()
    fileprivate var gyroReadings = [Vector3]()
    fileprivate var gyroReadingNextId = 0
    fileprivate var gyroCorrectReadings = 0

    // MARK: - ViewController
    override func awakeFromNib() {
        super.awakeFromNib()

        // Page View Controller setup
        pageViewControllerIds = GyroscopeViewController.kPageControllerIds
    }

    override func viewDidLoad() {
        // Initialize super
        super.viewDidLoad()

        // 3D Setup
        sceneSetup()

        // Start
        reset()

        // Debug
        if GyroscopeViewController.kSimulateReads {
            // Read file
            let path = Bundle.main.path(forResource: GyroscopeViewController.kSimulateReadsFileName, ofType: "txt")!
            let content = try! String(contentsOfFile: path, encoding: .ascii)
            lines = content.components(separatedBy: "\n")
        }

        // Start
        isCalibrating = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if GyroscopeViewController.kSimulateReadsInBulk {
            for line in lines {
                //DLog("\(line)")
                let kRawPrefix = "Raw:"
                if line.hasPrefix(kRawPrefix) {
                    let valuesString = line.substring(from: line.index(line.startIndex, offsetBy: kRawPrefix.count))
                    //                DLog("\(values)")
                    let values = valuesString.components(separatedBy: ",")
                    let accel = [Int16(values[0])!, Int16(values[1])!, Int16(values[2])!]
                    let gyro = [Int16(values[3])!, Int16(values[4])!, Int16(values[5])!]
                    let mag = [Int16(values[6])!, Int16(values[7])!, Int16(values[8])!]

                    calibration.addData(accelX: accel[0], accelY: accel[1], accelZ: accel[2], gyroX: gyro[0], gyroY: gyro[1], gyroZ: gyro[2], magX: mag[0], magY: mag[1], magZ: mag[2])

                    let orientation = calibration.currentOrientation

                    if let lastUsedIndex = calibration.lastUsedIndex(), let point = calibration.applyCalibration(index: lastUsedIndex) {
                        let orientatedPoint = point * orientation

                        // Axis-angle calculation:
                        // if v1 and v2 are normalised so that |v1|=|v2|=1, then,
                        // angle = acos(v1•v2)
                        // axis = norm(v1 x v2)

                        let v1 = orientatedPoint.normalized()
                        let v2  = Vector3(1, 0, 0)
                        let angle = acos(v1.dot(v2))
                        let axis = v1.cross(v2).normalized()

                        let axisOrientation = Vector4(axis.x, axis.y, axis.z, angle)
                        currentOrientation = axisOrientation

                        // Add gyro reading
                        addReading(gyroX: gyro[0], gyroY: gyro[1], gyroZ: gyro[2])
                    }

                    updateUI()
                }
            }
        }
    }

    override func detailViewControlleratIndex(_ index: Int) -> PageContentViewController? {
        let pageContentViewController = super.detailViewControlleratIndex(index)

        if let gyroscopePageContentViewController = pageContentViewController as? GyroscopePageContentViewController {
            gyroscopePageContentViewController.gyroVector = accumulatedGyroVector()
            gyroscopePageContentViewController.delegate = self
        }
        pageContentViewController?.updateUI()

        return pageContentViewController
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    fileprivate func reset() {
        clearRxCache()
        calibration.reset()
        gyroReadingNextId = 0
        gyroCorrectReadings = 0
        gyroReadings = [Vector3](repeating: .zero, count: Preferences.gyroReadingsCount)
    }

    // MARK: - Data Received
    override func onRawData(accelX: Int16, accelY: Int16, accelZ: Int16, gyroX: Int16, gyroY: Int16, gyroZ: Int16, magX: Int16, magY: Int16, magZ: Int16) {
        // DLog("Raw:\(accelX),\(accelY),\(accelZ),\(gyroX),\(gyroY),\(gyroZ),\(magX),\(magY),\(magZ)")

        clearRxCache()       // Avoid piling commands on the uart cache

        if isCalibrating {
            // Update calibration for 3d view
            calibration.addData(accelX: accelX, accelY: accelY, accelZ: accelZ, gyroX: gyroX, gyroY: gyroY, gyroZ: gyroZ, magX: magX, magY: magY, magZ: magZ)

            let orientation = calibration.currentOrientation

            if let lastUsedIndex = calibration.lastUsedIndex(), let point = calibration.applyCalibration(index: lastUsedIndex) {
                let orientatedPoint = point * orientation

                // Axis-angle calculation:
                // if v1 and v2 are normalised so that |v1|=|v2|=1, then,
                // angle = acos(v1•v2)
                // axis = norm(v1 x v2)

                let v1 = orientatedPoint.normalized()
                let v2  = Vector3(1, 0, 0)
                let angle = acos(v1.dot(v2))
                let axis = v1.cross(v2).normalized()

                let axisOrientation = Vector4(axis.x, axis.y, axis.z, angle)
                currentOrientation = axisOrientation

                // Add gyro reading
                addReading(gyroX: gyroX, gyroY: gyroY, gyroZ: gyroZ)
            }
        }
    }

    fileprivate func addReading(gyroX: Int16, gyroY: Int16, gyroZ: Int16) {

        // Add reading
        let x = Scalar(gyroX)
        let y = Scalar(gyroY)
        let z = Scalar(gyroZ)

        DLog("x: \(x), y: \(y), z: \(z)")

        gyroReadings[gyroReadingNextId % gyroReadings.count] = Vector3(x, y, z)
        gyroReadingNextId += 1

        let averageGyroVector = accumulatedGyroVector()

        // Check if is stable (last kNumReadingsStable readings should not deviate from averageGyroVector more than kReadingsMaxDifferenceToBeStable)
        var diffTotal: Float = 0
        for i in 0..<min(GyroscopeViewController.kNumReadingsToCheckForStable, gyroReadings.count) {
            let varianceVector = averageGyroVector - gyroReadings[mod(gyroReadingNextId - i, gyroReadings.count)]
            diffTotal += abs(varianceVector.x) + abs(varianceVector.y) + abs(varianceVector.z)
        }
        //DLog("diffTotal: \(diffTotal)")

        if diffTotal <  GyroscopeViewController.kReadingsMaxDifferenceToBeStable * Float(GyroscopeViewController.kNumReadingsToCheckForStable) {
            gyroCorrectReadings += 1
        } else {
            gyroCorrectReadings = 0
        }

        // Update progress in pages
        for i in 0..<cachedPageViewControllers.count {
            if let detailViewController = cachedPageViewControllers[i] as? GyroscopePageContentViewController {
                detailViewController.gyroVector = averageGyroVector
                detailViewController.progress = min(1, Float(gyroCorrectReadings) / Float(gyroReadings.count))
                DispatchQueue.main.async {
                    detailViewController.updateUI()
                }
            }
        }

        // Check if finished
        if gyroCorrectReadings >=  gyroReadings.count {
            DLog("calibration finished")
            isCalibrating = false

            // Go to results page
            DispatchQueue.main.async { [weak self] in
                self?.gotoPage(1)
            }

            /*
            // Send calibration to phone
            var messageData = "G".data(using: .utf8)!
            messageData.append(UnsafeBufferPointer(start: &averageGyroVector.x, count: 4))
            messageData.append(UnsafeBufferPointer(start: &averageGyroVector.y, count: 4))
            messageData.append(UnsafeBufferPointer(start: &averageGyroVector.z, count: 4))
            
            blePeripheral?.uartSend(data: messageData)
 */
        }
    }

    fileprivate func mod(_ a: Int, _ n: Int) -> Int {
        precondition(n > 0, "modulus must be positive")
        let r = a % n
        return r >= 0 ? r : r + n
    }

    fileprivate func accumulatedGyroVector() -> Vector3 {

        var accum = Vector3.zero

        for vector in gyroReadings {
            accum = accum + vector
        }

        let count = Float(gyroReadings.count)
        accum =  Vector3(accum.x / count, accum.y / count, accum.z / count)

        return accum
    }

    // MARK: - UI
    override func updateUI() {
        super.updateUI()

        // Scene
        updateScene()
    }

    // MARK: - Scene3D
    private func sceneSetup() {
        // Load base
        let scene = SCNScene(named: "gyroscope.scn")!

        // Axis
        axisNode = addAxisGeometry(scene)

        // Setup scene
        sceneView.scene = scene
        sceneView.autoenablesDefaultLighting = true
    }

    //var angle: Float = 0
    private func updateScene() {
        guard isCalibrating else {
            return
        }

        axisNode.rotation = SCNVector4(currentOrientation.x, currentOrientation.y, currentOrientation.z, currentOrientation.z)
    }

    func angle(start: Vector3, mid: Vector3, end: Vector3) -> Double {
        let v1 = start - mid
        let v2 = end - mid
        let v1norm = v1.normalized()
        let v2norm = v2.normalized()

        let res = v1norm.x * v2norm.x + v1norm.y * v2norm.y + v1norm.z * v2norm.z
        let angle: Double = Double(acos(res))
        return angle
    }
}

// MARK: - MagnetometerPageContentViewControllerDelegate
extension GyroscopeViewController: GyroscopePageContentViewControllerDelegate {
    func onGyroscopeRestart() {
        isCalibrating = true
        reset()
        updateUI()
    }

    func onGyroscopeParametersChanged() {
        reset()
        isCalibrating = true
    }
}
