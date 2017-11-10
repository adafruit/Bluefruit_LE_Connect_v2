//
//  MagnetometerViewController.swift
//  Calibration
//
//  Created by Antonio García on 03/11/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit
import SceneKit

class MagnetometerViewController: CalibrationUartSamplerViewController {

    // Debug
    fileprivate static let kSimulateReads =  Config.isDebugEnabled && false // true
    fileprivate static let kSimulateReadsFileName = "mag_test_1"
    fileprivate static let kSimulateReadsInBulk = kSimulateReads && false

    fileprivate var lines: [String]!
    fileprivate var currentLine = 0

    // PageViewController
    fileprivate static let kPageControllerIds = ["MagnetometerProgress2ViewController", //"MagnetometerPageOverviewViewController", 
        "MagnetometerPageMatrixViewController"]

    // Data
    fileprivate var calibration = Calibration()
    fileprivate var spherePointsNode: SCNNode!
    fileprivate var lastPointNode: SCNNode!

    // MARK: - ViewController
    override func awakeFromNib() {
        super.awakeFromNib()

           // Page View Controller setup
        pageViewControllerIds = MagnetometerViewController.kPageControllerIds
    }

    override func viewDidLoad() {
        // Initialize super
        super.viewDidLoad()

        // 3D Setup
        sceneSetup()

        // Debug
        if MagnetometerViewController.kSimulateReads {
            // Read file
            let path = Bundle.main.path(forResource: MagnetometerViewController.kSimulateReadsFileName, ofType: "txt")!
            let content = try! String(contentsOfFile: path, encoding: .ascii)
            lines = content.components(separatedBy: "\n")
        }

        // Start
        isCalibrating = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if MagnetometerViewController.kSimulateReadsInBulk {
            for line in lines {
                //DLog("\(line)")
                let kRawPrefix = "Raw:"
                if line.hasPrefix(kRawPrefix) {
                    let valuesString = line.substring(from: line.characters.index(line.startIndex, offsetBy: kRawPrefix.count))
                    //                DLog("\(values)")
                    let values = valuesString.components(separatedBy: ",")
                    let accel = [Int16(values[0])!, Int16(values[1])!, Int16(values[2])!]
                    let gyro = [Int16(values[3])!, Int16(values[4])!, Int16(values[5])!]
                    let mag = [Int16(values[6])!, Int16(values[7])!, Int16(values[8])!]

                    calibration.addData(accelX: accel[0], accelY: accel[1], accelZ: accel[2], gyroX: gyro[0], gyroY: gyro[1], gyroZ: gyro[2], magX: mag[0], magY: mag[1], magZ: mag[2])

                    updateUI()
                }
            }
        }
    }

    override func detailViewControlleratIndex(_ index: Int) -> PageContentViewController? {
        let pageContentViewController = super.detailViewControlleratIndex(index)

        if let magnetometerPageContentViewController = pageContentViewController as? MagnetometerPageContentViewController {
            magnetometerPageContentViewController.calibration = calibration
            magnetometerPageContentViewController.delegate = self
        }
        pageContentViewController?.updateUI()

        return pageContentViewController
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Data Received
    override func onRawData(accelX: Int16, accelY: Int16, accelZ: Int16, gyroX: Int16, gyroY: Int16, gyroZ: Int16, magX: Int16, magY: Int16, magZ: Int16) {

        clearRxCache()       // Avoid piling commands on the uart cache

        if !MagnetometerViewController.kSimulateReads {
            DLog("Raw:\(accelX),\(accelY),\(accelZ),\(gyroX),\(gyroY),\(gyroZ),\(magX),\(magY),\(magZ)")

            calibration.addData(accelX: accelX, accelY: accelY, accelZ: accelZ, gyroX: gyroX, gyroY: gyroY, gyroZ: gyroZ, magX: magX, magY: magY, magZ: magZ)

            if !MagnetometerViewController.kUseUpdateTimer {
                // Update UI
                updateEventSource?.or(data: 1)
            }
        } else if currentLine < lines.count && !MagnetometerViewController.kSimulateReadsInBulk {
            let line = lines[currentLine]
            currentLine = currentLine + 1
            let kRawPrefix = "Raw:"
            if line.hasPrefix(kRawPrefix) {
                DLog(line)
                let valuesString = line.substring(from: line.index(line.startIndex, offsetBy: kRawPrefix.count))
                //                DLog("\(values)")
                let values = valuesString.components(separatedBy: ",")
                let accelX  = Int16(values[0])
                let accelY  = Int16(values[1])
                let accelZ  = Int16(values[2])
                let gyroX  = Int16(values[3])
                let gyroY  = Int16(values[4])
                let gyroZ  = Int16(values[5])
                let magX  = Int16(values[6])
                let magY  = Int16(values[7])
                let magZ  = Int16(values[8])

                if let accelX = accelX, let accelY = accelY, let accelZ = accelZ, let gyroX = gyroX, let gyroY = gyroY, let gyroZ = gyroZ, let magX = magX, let magY = magY, let magZ = magZ {

                    let accel = [accelX, accelY, accelZ]
                    let gyro = [gyroX, gyroY, gyroZ]
                    let mag = [magX, magY, magZ]

                    calibration.addData(accelX: accel[0], accelY: accel[1], accelZ: accel[2], gyroX: gyro[0], gyroY: gyro[1], gyroZ: gyro[2], magX: mag[0], magY: mag[1], magZ: mag[2])

                    if !MagnetometerViewController.kUseUpdateTimer {
                        // Update UI
                        updateEventSource?.or(data: 1)
                    }

                } else {
                    DLog("Warning: wrong reading received")
                }
            }
        }
    }

    // MARK: - UI
    override func updateUI() {
        super.updateUI()

        // Send Button
        let gaps = calibration.surfaceGapError()
        let variance = calibration.magnitudeVarianceError()
        let wobble = calibration.wobbleError()
        let fiterror = calibration.sphericalFitError()

        if gaps < Calibration.kGapTarget && variance < Calibration.kVarianceTarget && wobble < Calibration.kWobbleTarget && fiterror < Calibration.kFitErrorTarget {
            setSendButton(enabled: true)
        } else if gaps > 20 && variance > 5 && wobble > 5 && fiterror > 6 {
            setSendButton(enabled: false)
        }

        // Gaps, Variance, Wobble, FitError
        if currentPage >= 0 && currentPage < cachedPageViewControllers.count {
            if let detailViewController = cachedPageViewControllers[currentPage] {
                detailViewController.updateUI()
            }
        }

        // Scene
        updateScene()
    }

    private func setSendButton(enabled: Bool) {
        guard enabled else {
            return
        }

        // Stop calibration
        DLog("calibration finished")
        isCalibrating = false
        stopDisplayLink()

        // Go to results page
        DispatchQueue.main.async { [weak self] in
            self?.gotoPage(1)
        }

        /*
        // Send calibration to phone
        var hardIron = calibration.hardIron()
        var magneticField = calibration.magneticField()
        var magneticMapping = calibration.magneticMapping()
        
        var messageData = "M".data(using: .utf8)!
        messageData.append(UnsafeBufferPointer(start: &hardIron.x, count: 4))
        messageData.append(UnsafeBufferPointer(start: &hardIron.y, count: 4))
        messageData.append(UnsafeBufferPointer(start: &hardIron.z, count: 4))
        
        messageData.append(UnsafeBufferPointer(start: &magneticField, count: 4))
        
        messageData.append(UnsafeBufferPointer(start: &magneticMapping.m11, count: 4))
        messageData.append(UnsafeBufferPointer(start: &magneticMapping.m22, count: 4))
        messageData.append(UnsafeBufferPointer(start: &magneticMapping.m33, count: 4))
        messageData.append(UnsafeBufferPointer(start: &magneticMapping.m12, count: 4))
        messageData.append(UnsafeBufferPointer(start: &magneticMapping.m13, count: 4))
        messageData.append(UnsafeBufferPointer(start: &magneticMapping.m23, count: 4))
        
        blePeripheral?.uartSend(data: messageData)
 */
    }

    // MARK: - Scene3D
    private func sceneSetup() {
        // Load base
        let scene = SCNScene(named: "magnetometer.scn")!
        spherePointsNode = scene.rootNode.childNode(withName: "spherePoints", recursively: false)!

        // Axis
        let _ = addAxisGeometry(scene)

        // Dummy points
        for _ in 0..<Calibration.MagCalibration.kMagBufferSize {
            let pointGeometry = SCNSphere(radius: 0.01)
            pointGeometry.segmentCount = 6         // default: 24
            pointGeometry.firstMaterial!.diffuse.contents = UIColor.white.withAlphaComponent(0.7)
            //pointGeometry.firstMaterial!.specular.contents = UIColor.white
            let pointNode = SCNNode(geometry: pointGeometry)
            spherePointsNode.addChildNode(pointNode)
        }

        // Last Point
        let pointGeometry = SCNSphere(radius: 0.015)
        pointGeometry.segmentCount = 12         // default: 24
        pointGeometry.firstMaterial!.diffuse.contents = UIColor.yellow.withAlphaComponent(1)

        //pointGeometry.firstMaterial!.specular.contents = UIColor.white
        lastPointNode = SCNNode(geometry: pointGeometry)
        scene.rootNode.addChildNode(lastPointNode)

        // Setup scene
        sceneView.scene = scene
        sceneView.autoenablesDefaultLighting = true
    }

    private func updateScene() {
        calibration.qualityReset()

        // Points
        let orientation = calibration.currentOrientation

        let kScale = Vector3(0.0105, 0.0105, 0.0105)
        let kOffset = Vector3(0, 0, 0)

        let numPoints = min(Calibration.MagCalibration.kMagBufferSize, spherePointsNode.childNodes.count)
        for i in 0..<numPoints {
            let pointNode = spherePointsNode.childNodes[i]

            if let point = calibration.applyCalibration(index: i) {
                calibration.qualityUpdate(point: point)

                let orientatedPoint = point * orientation
                let drawPoint = orientatedPoint * kScale + kOffset

                pointNode.pivot = SCNMatrix4MakeTranslation(drawPoint.x, drawPoint.y, drawPoint.z)
                pointNode.isHidden = false

                // DLog("vis \(i) x:\(point.x) y:\(point.y) z:\(point.z), qx:\(orientation.x) y:\(orientation.y) z:\(orientation.z) w:\(orientation.w)")
            } else {
                pointNode.isHidden = true
            }
        }

        // Last received point
        if let lastUsedIndex = calibration.lastUsedIndex() {
            let node = spherePointsNode.childNodes[lastUsedIndex]
            lastPointNode.pivot = node.pivot
            lastPointNode.isHidden = node.isHidden
        } else {
             lastPointNode.isHidden = true
        }
    }
}

// MARK: - MagnetometerPageContentViewControllerDelegate
extension MagnetometerViewController: MagnetometerPageContentViewControllerDelegate {
    func onMagnetometerRestart() {
        clearRxCache()
        isCalibrating = true
        calibration.reset()
        updateUI()
    }

    func onMagnetometerParametersChanged() {
        updateUI()
    }
}
