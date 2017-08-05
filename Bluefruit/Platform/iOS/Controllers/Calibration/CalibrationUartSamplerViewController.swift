//
//  CalibrationUartSamplerViewController.swift
//  Calibration
//
//  Created by Antonio on 11/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit
import SceneKit

class CalibrationUartSamplerViewController: CalibrationUartViewController {
    // Config
    static let kUseUpdateTimer = true
    fileprivate static let kPreferredFramesPerSecond: Int = 20 //0       // Default hardware value

    // Main UI
    @IBOutlet weak var sceneView: SCNView!
    @IBOutlet weak var detailsView: UIView!
    fileprivate let pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
    @IBOutlet weak var pageLeftButton: UIButton!
    @IBOutlet weak var pageRightButton: UIButton!

    // 3D Scene
    fileprivate var displayLink: CADisplayLink?

    // PageViewController
    var pageViewControllerIds = [String]()
    var currentPage = 0 {
        didSet {
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.3) { [unowned self] in
                    self.pageLeftButton?.alpha = self.currentPage > 0 ? 1:0
                    self.pageRightButton?.alpha = self.currentPage < self.pageViewControllerIds.count-1 ? 1:0
                }
            }
        }
    }
    var cachedPageViewControllers = [PageContentViewController?]()

    // Timer
    var updateEventSource: DispatchSourceUserDataOr?

    // Data
    fileprivate var uartManager: UartDataManager! // = UartDataManager(delegate: self)

    var isCalibrating = false {
        didSet {
            if isCalibrating {
                startDiplayLink()
            } else {
                stopDisplayLink()
            }

            for i in 0..<cachedPageViewControllers.count {
                if let detailViewController = cachedPageViewControllers[i] {
                    detailViewController.isCalibrating = isCalibrating
                }
            }
        }
    }

    // MARK: - ViewController
    override func viewDidLoad() {
        super.viewDidLoad()

        uartManager = UartDataManager(delegate: self)

        // Init cached view controllers
        for _ in 0..<pageViewControllerIds.count {
            cachedPageViewControllers.append(nil)
        }

        // Page View Controller setup
        pageViewController.dataSource = self
        pageViewController.delegate = self
        pageViewController.setViewControllers([detailViewControlleratIndex(0)!], direction: .forward, animated: false, completion: nil)

        pageLeftButton?.alpha = 0
        pageRightButton?.alpha = 1

        if let subview = pageViewController.view {
            addChildViewController(pageViewController)
            subview.translatesAutoresizingMaskIntoConstraints = false
            detailsView.insertSubview(subview, at: 0)
            pageViewController.didMove(toParentViewController: self)

            let variableBindings: [String: AnyObject] = ["subview": subview]
            detailsView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[subview]-0-|", options: [], metrics: nil, views: variableBindings))
            detailsView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[subview]-0-|", options: [], metrics: nil, views: variableBindings))
        }

        // Timer setup
        if !CalibrationUartSamplerViewController.kUseUpdateTimer {
            updateEventSource = DispatchSource.makeUserDataOrSource(queue: .main)
            updateEventSource!.setEventHandler { [weak self] in
                self?.updateUI()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Uart start
        start { [weak self] error in
            guard let context = self else { return }

            guard error == nil else {
                DispatchQueue.main.async { [unowned context] in
                    DLog("Error initializing uart")
                    showErrorAlert(from: context, title: "Error", message: "Uart protocol can not be initialized")

                    if let blePeripheral = context.blePeripheral {
                        BleManager.sharedInstance.disconnect(from: blePeripheral)
                    }
                }
                return
            }

            // Started
            DLog("Uart started")
        }

        // UI
        updateUI()

        if !CalibrationUartSamplerViewController.kUseUpdateTimer {
            updateEventSource!.resume()
        } else {
            if isCalibrating {
                startDiplayLink()
            }
        }

        // Receive any pending data
        if let identifier = blePeripheral?.identifier {
            uartManager.clearRxCache(peripheralIdentifier: identifier)
        }
    }

    func start(uartReadyCompletion:@escaping ((Error?) -> (Void))) {
        DLog("calibration uart start")

        // Enable Uart
        blePeripheral?.uartEnable(uartRxHandler: uartManager.rxDataReceived) { error in
            uartReadyCompletion(error)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if !MagnetometerViewController.kUseUpdateTimer {
            updateEventSource?.suspend()
            //        updateEventSource?.cancel()
            //        updateEventSource = nil
        } else {
            stopDisplayLink()
        }
    }

    deinit {
        if !MagnetometerViewController.kUseUpdateTimer {
            updateEventSource?.cancel()
            //updateEventSource = nil;
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - UI
    func detailViewControlleratIndex(_ index: Int) -> PageContentViewController? {
        // Override in subclasses for specific initilization

        guard index >= 0 && index < pageViewControllerIds.count else {
            return nil
        }

        if let viewController = cachedPageViewControllers[index] {
            return viewController
        } else {
            let viewControllerId = pageViewControllerIds[index]
            let viewController = storyboard?.instantiateViewController(withIdentifier: viewControllerId) as! PageContentViewController
            viewController.view.tag = index
            viewController.isCalibrating = isCalibrating
            cachedPageViewControllers[index] = viewController
            return viewController
        }
    }

    func gotoPage(_ pageId: Int) {
        if let viewController = detailViewControlleratIndex(pageId) {
            pageViewController.setViewControllers([viewController], direction: pageId < currentPage ? .reverse:.forward, animated: true, completion: nil)
            currentPage = pageId
        }
    }

    func updateUI() {
        // Override in subclasses
    }

    func startDiplayLink() {
        stopDisplayLink()

        displayLink = CADisplayLink(target: self, selector: #selector(updateTimerFired))
        if #available(iOS 10.0, *) {
            displayLink?.preferredFramesPerSecond = MagnetometerViewController.kPreferredFramesPerSecond
        } else {
            DLog("Warning: CADisplayLink.preferredFramesPerSecond not available on iOS9")
        }
        displayLink?.add(to: RunLoop.current, forMode: RunLoopMode.commonModes)
    }

    func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc func updateTimerFired() {
        updateUI()
    }

    // MARK: - 3D Scene
    func addAxisGeometry(_ scene: SCNScene) -> SCNNode {
        let axisNode = scene.rootNode.childNode(withName: "axis", recursively: true)!

        let axisLenght: CGFloat = 0.5
        let axisSizeFactor: CGFloat = 40
        let colors = [UIColor.red, UIColor.green, UIColor.blue]
        let angles = [SCNVector3(), SCNVector3(0, 0, GLKMathDegreesToRadians(90)), SCNVector3(0, -GLKMathDegreesToRadians(90), 0)]

        for i in 0..<3 {
            let boxGeometry = SCNBox(width: axisLenght, height: axisLenght/axisSizeFactor, length: axisLenght/axisSizeFactor, chamferRadius: axisLenght/axisSizeFactor)
            boxGeometry.firstMaterial!.diffuse.contents = colors[i]
            boxGeometry.firstMaterial!.specular.contents = UIColor.white
            let boxNode = SCNNode(geometry: boxGeometry)

            boxNode.pivot = SCNMatrix4MakeTranslation(-Float(axisLenght/2), 0, 0)
            boxNode.eulerAngles = angles[i]

            axisNode.addChildNode(boxNode)
        }

        return axisNode
    }

    @IBAction func onClickPreviousPage(_ sender: Any) {
        if currentPage > 0 {
            gotoPage(currentPage-1)
        }
    }

    @IBAction func onClickNextPage(_ sender: Any) {
        if currentPage < pageViewControllerIds.count-1 {
            gotoPage(currentPage + 1)
        }
    }

    // MARK: - Data
    func clearRxCache() {
        guard let identifier = blePeripheral?.identifier else { return }
        uartManager.clearRxCache(peripheralIdentifier: identifier)
    }

    func onRawData(accelX: Int16, accelY: Int16, accelZ: Int16, gyroX: Int16, gyroY: Int16, gyroZ: Int16, magX: Int16, magY: Int16, magZ: Int16) {

        // Override in subclasses
    }

    /*
     func onRawData(x: Float32, y: Float32, z: Float32)  {
     
     // Override in subclasses
     }*/

    func onOrientation(_ quaternion: Quaternion) {
        // Override in subclasses
    }
}

// MARK: - UIPageViewControllerDataSource
extension CalibrationUartSamplerViewController: UIPageViewControllerDataSource {

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        let index = viewController.view.tag
        guard index < presentationCount(for: pageViewController) && index != NSNotFound else {
            return nil
        }

        return detailViewControlleratIndex(index + 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {

        let index = viewController.view.tag
        guard index > 0 && index != NSNotFound else {
            return nil
        }

        return detailViewControlleratIndex(index - 1)
    }

    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return pageViewControllerIds.count < 2 ? 0:pageViewControllerIds.count     // Dont show points if less than 2
    }

    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        return 0
    }
}

// MARK: UIPageViewControllerDelegate
extension CalibrationUartSamplerViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed else { return }

        currentPage = pageViewController.viewControllers!.first!.view.tag
        DLog("currentPage: \(currentPage)")
    }
}

// MARK: - UartDelegate
extension CalibrationUartSamplerViewController: UartDataManagerDelegate {
    func onUartRx(data: Data, peripheralIdentifier: UUID) {
        // DLog("uart rx read (hex): \(hexDescription(data: data))")
        //DLog("uart rx read (utf8): \(String(data: data, encoding: .utf8) ?? "<invalid>")")

        guard peripheralIdentifier == blePeripheral?.identifier else { return }
        guard isCalibrating else { return }
        guard data.count >= 2 else { return }

        // Parse the received data
        var remainigData = data
        var isWaitingForMoreData = false

        while remainigData.count > 0 && !isWaitingForMoreData {
            // DLog("cbuffer (hex): \(hexDescription(data: remainigData))")

            switch remainigData[0] {

            case "R".asciiValue:            // Raw value
                let payLoadNumBytes = 9*2
                let numBytes = 1 + payLoadNumBytes
                if remainigData.count >= numBytes {

                    let data = remainigData.subdata(in: 1..<numBytes)
                    let accelX: Int16 = data.scanValue(start: 0, length: 2)
                    let accelY: Int16 = data.scanValue(start: 2, length: 2)
                    let accelZ: Int16 = data.scanValue(start: 4, length: 2)
                    let gyroX: Int16 = data.scanValue(start: 6, length: 2)
                    let gyroY: Int16 = data.scanValue(start: 8, length: 2)
                    let gyroZ: Int16 = data.scanValue(start: 10, length: 2)
                    let magX: Int16 = data.scanValue(start: 12, length: 2)
                    let magY: Int16 = data.scanValue(start: 14, length: 2)
                    let magZ: Int16 = data.scanValue(start: 16, length: 2)

                    onRawData(accelX: accelX, accelY: accelY, accelZ: accelZ, gyroX: gyroX, gyroY: gyroY, gyroZ: gyroZ, magX: magX, magY: magY, magZ: magZ)

                    // Remove processed data
                    remainigData.removeFirst(numBytes)
                } else {
                    isWaitingForMoreData = true
                }

            case "V".asciiValue:            // Euler vector
                let payLoadNumBytes = 4*4
                let numBytes = 1 + payLoadNumBytes
                if remainigData.count >= numBytes {

                    let data = remainigData.subdata(in: 1..<numBytes)
                    let w: Float32 = data.scanValue(start: 0, length: 4)
                    let x: Float32 = data.scanValue(start: 4, length: 4)
                    let y: Float32 = data.scanValue(start: 8, length: 4)
                    let z: Float32 = data.scanValue(start: 12, length: 4)

                    let q = Quaternion(x, y, z, w)
                    //onRawData(quaternion: q)
                    onOrientation(q)

                    // Remove processed data
                    remainigData.removeFirst(numBytes)
                } else {
                    isWaitingForMoreData = true
                }

            default:
                // Unrecognized data. Remove first byte and try again
                remainigData.removeFirst()
                break
            }
        }

        let numBytesProcessed = data.count - remainigData.count
        uartManager.removeRxCacheFirst(n: numBytesProcessed, peripheralIdentifier: peripheralIdentifier)
    }
}
