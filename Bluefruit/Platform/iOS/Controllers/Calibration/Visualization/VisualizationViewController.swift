//
//  VisualizationViewController.swift
//  Calibration
//
//  Created by Antonio on 14/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit
import SceneKit

class VisualizationViewController: CalibrationUartSamplerViewController {
    // Config
    fileprivate static let kIsQuatSpeedDebugEnabled = true

    // UI
    @IBOutlet weak var dataReveivedSpeedLabel: UILabel!

    // PageViewController
    fileprivate static let kPageControllerIds = ["VisualizationProgressViewController"]

    // 3D Scene
    fileprivate var currentOrientation = Quaternion.identity
    fileprivate var geometry: SCNNode?
    fileprivate var model: SCNNode?

    fileprivate var originOffset = Quaternion.identity

    // Debug
    fileprivate var numQuatsReceived = 0
    fileprivate var quatReceivedStartingTime: TimeInterval = 0
    fileprivate var lastQuatPerSecondValue: Double?

    // MARK: - ViewController
    override func awakeFromNib() {
        super.awakeFromNib()

        // Page View Controller setup
        pageViewControllerIds = VisualizationViewController.kPageControllerIds
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // 3D Setup
        sceneSetup()

        // UI
        dataReveivedSpeedLabel.isHidden = !VisualizationViewController.kIsQuatSpeedDebugEnabled

        // Start
        reset()
        isCalibrating = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func detailViewControlleratIndex(_ index: Int) -> PageContentViewController? {
        let pageContentViewController = super.detailViewControlleratIndex(index)

        if let visualizationPageContentViewController = pageContentViewController as? VisualizationProgressViewController {
            visualizationPageContentViewController.delegate = self
        }
        pageContentViewController?.updateUI()

        return pageContentViewController
    }

    fileprivate func reset() {
        clearRxCache()
    }

    // MARK: - Data Received
    override func onRawData(accelX: Int16, accelY: Int16, accelZ: Int16, gyroX: Int16, gyroY: Int16, gyroZ: Int16, magX: Int16, magY: Int16, magZ: Int16) {
        // DLog("Raw:\(accelX),\(accelY),\(accelZ),\(gyroX),\(gyroY),\(gyroZ),\(magX),\(magY),\(magZ)")

       //*/ UartManager.sharedInstance.clearRxCache()       // Avoid piling commands on the uart cache
    }

    // MARK: - Data
    override func onOrientation(_ q: Quaternion) {

        let x = q.x
        let y = Preferences.visualizationSwitchYZ ? q.z:q.y
        let z = Preferences.visualizationSwitchYZ ? q.y:q.z

        currentOrientation = Quaternion((Preferences.visualizationXAxisInverted ? 1:-1) * x, (Preferences.visualizationYAxisInverted ? 1:-1) * y, (Preferences.visualizationZAxisInverted ? 1:-1) * z, q.w)

        DLog("orientation: x:\(currentOrientation.x), y:\(currentOrientation.y), z:\(currentOrientation.z), w:\(currentOrientation.w)")

        // Debug
        if VisualizationViewController.kIsQuatSpeedDebugEnabled {
            if numQuatsReceived == 0 {
                quatReceivedStartingTime = CACurrentMediaTime()
            }
            numQuatsReceived += 1
        }
    }

    // MARK: - UI
    override func updateUI() {
        super.updateUI()

        // Scene
        updateScene()

        // Update orientation parameters
        for i in 0..<cachedPageViewControllers.count {
            if let progressViewController = cachedPageViewControllers[i] as? VisualizationProgressViewController {
                progressViewController.orientation = currentOrientation
                progressViewController.originOffset = originOffset
                progressViewController.updateUI()
            }
        }

        // Update debug data
        let currentTime = CACurrentMediaTime() - quatReceivedStartingTime
        if currentTime > 1 {        // Reset counters after 1 second
            lastQuatPerSecondValue = Double(numQuatsReceived) / currentTime
            numQuatsReceived = 0
        }
        
        dataReveivedSpeedLabel.text = lastQuatPerSecondValue != nil ? String(format: "%.1f Quat/s", lastQuatPerSecondValue!) : nil

    }

    // MARK: - Scene3D
    private func sceneSetup() {
        // Load base
        let scene = SCNScene(named: "visualization.scn")!
        geometry = scene.rootNode.childNode(withName: "geometry", recursively: false)!
        model = geometry?.childNode(withName: "model", recursively: false)!

        // Axis
        let _ = addAxisGeometry(scene)

        // Setup scene
        sceneView.scene = scene
        sceneView.autoenablesDefaultLighting = true
        sceneView.isUserInteractionEnabled = false

        // Set initial values
        updateAxisInverted()
    }

    //var angle: Float = 0
    fileprivate func updateScene() {
        guard isCalibrating else {
            return
        }

        geometry?.orientation = SCNQuaternion(currentOrientation * originOffset)
    }

    fileprivate func updateAxisInverted() {
        model?.scale = SCNVector3(Preferences.visualizationXAxisFlipped ? -1:1, Preferences.visualizationYAxisFlipped ? -1:1, Preferences.visualizationZAxisFlipped ? -1:1)

        DLog("scale: \(geometry!.scale.x), \(geometry!.scale.y), \(geometry!.scale.z)")

    }
}

extension VisualizationViewController: VisualizationProgressViewControllerDelegate {
    func onVisualizationParametersChanged() {
        updateAxisInverted()
        updateScene()
    }

    func onVisualizationOriginSet() {
        originOffset = currentOrientation.inverse
        updateUI()
    }

    func onVisualizationOriginReset() {
        originOffset = Quaternion.identity
        updateUI()

    }
}
