//
//  NeopixelModeViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 24/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class NeopixelModeViewController: PeripheralModeViewController {

    // Constants
    private static let kLedWidth: CGFloat = 44
    private static let kLedHeight: CGFloat = 44
    private static let kDefaultLedColor = UIColor(hex: 0xffffff)!
    private static let kDefaultComponent: NeopixelModuleManager.Components = Config.isDebugEnabled ? .grbw : .grb

    // UI
    @IBOutlet weak var statusView: UIView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var connectButton: UIButton!

    @IBOutlet weak var paletteCollection: UICollectionView!

    @IBOutlet weak var boardScrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var contentViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentViewHeightConstrait: NSLayoutConstraint!

    @IBOutlet weak var colorPickerContainerView: UIView!
    @IBOutlet weak var boardControlsView: UIView!
    @IBOutlet weak var colorPickerWComponentColorView: UIView!

    @IBOutlet weak var rotationView: UIView!

    // Data
    fileprivate var defaultPalette: [String] = []
    fileprivate var neopixel: NeopixelModuleManager!
    fileprivate var board: NeopixelModuleManager.Board?
    fileprivate var components = NeopixelModeViewController.kDefaultComponent
    fileprivate var is400HzEnabled = false
    private var ledViews = [UIView]()

    fileprivate var currentColor: UIColor = UIColor.red
    fileprivate var colorW: Float = 0
    private var contentRotationAngle: CGFloat = 0

    private var boardMargin = UIEdgeInsets.zero
    private var boardCenterScrollOffset = CGPoint()

    private var isSketchTooltipAlreadyShown = false

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Title
        let localizationManager = LocalizationManager.sharedInstance
        let name = blePeripheral?.name ?? LocalizationManager.sharedInstance.localizedString("scanner_unnamed")
        self.title = traitCollection.horizontalSizeClass == .regular ? String(format: localizationManager.localizedString("neopixels_navigation_title_format"), arguments: [name]) : localizationManager.localizedString("neopixels_tab_title")
        
        // Init
        assert(blePeripheral != nil)
        neopixel = NeopixelModuleManager(blePeripheral: blePeripheral!)
        board = NeopixelModuleManager.Board.loadStandardBoard(0)

        // Read palette from resources
        let url = Bundle.main.url(forResource: "NeopixelDefaultPalette", withExtension: "plist")!
        let data = try! Data(contentsOf: url)
        defaultPalette = try! PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! [String]

        // UI
        statusView.layer.borderColor = UIColor.white.cgColor
        statusView.layer.borderWidth = 1

        boardScrollView.layer.borderColor = UIColor.white.cgColor
        boardScrollView.layer.borderWidth = 1

        colorPickerContainerView.layer.cornerRadius = 4
        colorPickerContainerView.layer.masksToBounds = true

        // Setup
        changeComponents(components, is400HkzEnabled: is400HzEnabled)
        createBoardUI()
        updatePickerColorButton(isSelected: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Start
        updateStatusUI(isWaitingResponse: true)
        neopixel.start { error in
            DispatchQueue.main.async { [weak self] in
                guard let context = self else { return  }

                guard error == nil else {
                    DLog("Error initializing uart")
                    context.dismiss(animated: true, completion: { [weak self] () -> Void in
                        if let context = self {
                            showErrorAlert(from: context, title: "Error", message: "Uart protocol can not be initialized")

                            if let blePeripheral = context.blePeripheral {
                                BleManager.sharedInstance.disconnect(from: blePeripheral)
                            }
                        }
                    })
                    return
                }

                // Uart Ready
                context.updateStatusUI(isWaitingResponse: false)
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Show tooltip alert
        if Preferences.neopixelIsSketchTooltipEnabled && !isSketchTooltipAlreadyShown {
            let localizationManager = LocalizationManager.sharedInstance
            let alertController = UIAlertController(title: localizationManager.localizedString("dialog_notice"), message: localizationManager.localizedString("neopixel_sketch_tooltip"), preferredStyle: .alert)

            let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler:nil)
            alertController.addAction(okAction)

            let dontshowAction = UIAlertAction(title: localizationManager.localizedString("dialog_dontshowagain"), style: .destructive) { (action) in
                Preferences.neopixelIsSketchTooltipEnabled = false
            }
            alertController.addAction(dontshowAction)

            self.present(alertController, animated: true, completion: nil)
            isSketchTooltipAlreadyShown = true
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        neopixel.stop()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let controller = segue.destination.popoverPresentationController

        if let boardSelectorViewController = segue.destination as? NeopixelBoardSelectorViewController {
            controller?.delegate = self

            boardSelectorViewController.onClickStandardBoard = { [unowned self] standardBoardIndex in
                guard let board = NeopixelModuleManager.Board.loadStandardBoard(standardBoardIndex) else { return }
                self.changeBoard(board)
            }

            boardSelectorViewController.onClickCustomLineStrip = { [unowned self] in
                self.showLineStripDialog()
            }
        } else if let componentSelectorViewController = segue.destination as? NeopixelComponentSelectorViewController {
            controller?.delegate = self

            componentSelectorViewController.selectedComponent = components
            componentSelectorViewController.onSetComponents = { [unowned self] (components: NeopixelModuleManager.Components, is400HkzEnabled: Bool) in
                self.changeComponents(components, is400HkzEnabled: is400HkzEnabled)
            }
        } else if let colorPickerViewController = segue.destination as? NeopixelColorPickerViewController {
            controller?.delegate = self

            colorPickerViewController.delegate = self
            colorPickerViewController.initialColor = currentColor
            colorPickerViewController.is4ComponentsEnabled = components.numComponents == 4
        }

    }

    private func changeComponents(_ components: NeopixelModuleManager.Components, is400HkzEnabled: Bool) {
        self.components = components
        self.is400HzEnabled = is400HkzEnabled
        colorPickerWComponentColorView.isHidden = components.numComponents != 4

        /*
        if neopixel.isBoardConfigured() {
            neopixel.setupNeopixel(board: self.board, components: components, is400HzEnabled: is400HkzEnabled, completion: <#T##((Bool) -> (Void))##((Bool) -> (Void))##(Bool) -> (Void)#>)
        }*/
        onClickConnect(self)

    }

    private func changeBoard(_ board: NeopixelModuleManager.Board) {
        self.board = board
        createBoardUI()
        neopixel.resetBoard()
        updateStatusUI(isWaitingResponse: false)
    }

    private func showLineStripDialog() {
        // Show dialog
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: nil, message: "Select line strip length", preferredStyle: .alert)

        let okAction = UIAlertAction(title: "Select", style: .default) { (_) in
            let stripLengthTextField = alertController.textFields![0] as UITextField

            if let text = stripLengthTextField.text, let stripLength = Int(text) {
                let board = NeopixelModuleManager.Board(name: "1x\(stripLength)", width: UInt8(stripLength), height:UInt8(1), stride: UInt8(stripLength))
                self.changeBoard(board)
            }
        }
        okAction.isEnabled = false
        alertController.addAction(okAction)

        alertController.addTextField { textField in
            textField.placeholder = "Enter Length"
            textField.keyboardType = .numberPad

            NotificationCenter.default.addObserver(forName: NSNotification.Name.UITextFieldTextDidChange, object: textField, queue: .main) { notification in
                okAction.isEnabled = textField.text != ""
            }
        }

        alertController.addAction(UIAlertAction(title: localizationManager.localizedString("dialog_cancel"), style: .cancel, handler: nil))

        self.present(alertController, animated: true, completion: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updateBoardPositionValues()
        setDefaultPositionAndScale(animated: true)
    }

    fileprivate func updateStatusUI(isWaitingResponse: Bool) {
        connectButton.isEnabled = !isWaitingResponse && (neopixel.isSketchDetected != true || (neopixel.isReady() && !neopixel.isBoardConfigured()))

        let isBoardConfigured = neopixel.isBoardConfigured()
        boardScrollView.alpha = isBoardConfigured ? 1.0:0.2
        boardControlsView.alpha = isBoardConfigured ? 1.0:0.2

        var statusMessage: String?
        if !neopixel.isReady() {
            statusMessage = "Waiting for Uart..."
        } else if neopixel.isSketchDetected == nil {
            statusMessage = "Ready to Connect"
        } else if neopixel.isSketchDetected! {
            if !neopixel.isBoardConfigured() {
                if isWaitingResponse {
                    statusMessage = "Waiting for Setup"
                } else {
                    statusMessage = "Ready to Setup"
                }
            } else {
                statusMessage = "Connected"
            }
        } else {
            if isWaitingResponse {
                statusMessage = "Checking Sketch..."
            }
            else {
                statusMessage = "Not detected"
            }
        }
        statusLabel.text = statusMessage
    }

    private func createBoardUI() {

        // Remove old views
        for ledView in ledViews {
            ledView.removeFromSuperview()
        }

        for subview in rotationView.subviews {
            subview.removeFromSuperview()
        }

        // Create views
        let ledBorderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        let ledCircleMargin: CGFloat = 1
        var k = 0
        ledViews = []
        if let board = board {
            boardScrollView.layoutIfNeeded()

            updateBoardPositionValues()

            //let boardMargin = UIEdgeInsetsMake(verticalMargin, horizontalMargin, verticalMargin, horizontalMargin)

            for j in 0..<board.height {
                for i in 0..<board.width {
                    let button = UIButton(frame: CGRect(x: CGFloat(i)*NeopixelModeViewController.kLedWidth+boardMargin.left, y: CGFloat(j)*NeopixelModeViewController.kLedHeight+boardMargin.top, width: NeopixelModeViewController.kLedWidth, height: NeopixelModeViewController.kLedHeight))
                    button.layer.borderColor = ledBorderColor
                    button.layer.borderWidth = 1
                    button.tag = k
                    button.addTarget(self, action: #selector(ledPressed(_:)), for: [.touchDown])
                    rotationView.addSubview(button)

                    let colorView = UIView(frame: CGRect(x: ledCircleMargin, y: ledCircleMargin, width: NeopixelModeViewController.kLedWidth-ledCircleMargin*2, height: NeopixelModeViewController.kLedHeight-ledCircleMargin*2))
                    colorView.isUserInteractionEnabled = false
                    colorView.layer.borderColor = ledBorderColor
                    colorView.layer.borderWidth = 2
                    colorView.layer.cornerRadius = NeopixelModeViewController.kLedWidth/2
                    colorView.layer.masksToBounds = true
                    colorView.backgroundColor = NeopixelModeViewController.kDefaultLedColor
                    ledViews.append(colorView)
                    button.addSubview(colorView)

                    k += 1
                }
            }

            contentViewWidthConstraint.constant = CGFloat(board.width) * NeopixelModeViewController.kLedWidth + boardMargin.left + boardMargin.right
            contentViewHeightConstrait.constant = CGFloat(board.height) * NeopixelModeViewController.kLedHeight + boardMargin.top + boardMargin.bottom
            boardScrollView.minimumZoomScale = 0.1
            boardScrollView.maximumZoomScale = 10
            setDefaultPositionAndScale(animated: false)
            boardScrollView.layoutIfNeeded()
        }

        boardScrollView.setZoomScale(1, animated: false)
    }

    private func updateBoardPositionValues() {
        if let board = board {
            boardScrollView.layoutIfNeeded()

            //let marginScale: CGFloat = 5
            //boardMargin = UIEdgeInsetsMake(boardScrollView.bounds.height * marginScale, boardScrollView.bounds.width * marginScale, boardScrollView.bounds.height * marginScale, boardScrollView.bounds.width * marginScale)
            boardMargin = UIEdgeInsetsMake(2000, 2000, 2000, 2000)

            let boardWidthPoints = CGFloat(board.width) * NeopixelModeViewController.kLedWidth
            let boardHeightPoints = CGFloat(board.height) * NeopixelModeViewController.kLedHeight

            let horizontalMargin = max(0, (boardScrollView.bounds.width - boardWidthPoints)/2)
            let verticalMargin = max(0, (boardScrollView.bounds.height - boardHeightPoints)/2)

            boardCenterScrollOffset = CGPoint(x: boardMargin.left - horizontalMargin, y: boardMargin.top - verticalMargin)
        }
    }

    private func setDefaultPositionAndScale(animated: Bool) {
        boardScrollView.setZoomScale(1, animated: animated)
        boardScrollView.setContentOffset(boardCenterScrollOffset, animated: animated)
    }

    @objc func ledPressed(_ sender: UIButton) {
        let isBoardConfigured = neopixel.isBoardConfigured()
        if let board = board, isBoardConfigured {
            let x = sender.tag % Int(board.width)
            let y = sender.tag / Int(board.width)
            DLog("led: (\(x)x\(y))")

            ledViews[sender.tag].backgroundColor = currentColor
            neopixel.setPixelColor(currentColor, colorW: colorW, x: UInt8(x), y: UInt8(y))
        }
    }

    // MARK: - Actions
    @IBAction func onClickConnect(_ sender: AnyObject) {
        updateStatusUI(isWaitingResponse: true)

        neopixel.connectNeopixel { [weak self] isDetected in
            guard let context = self else { return }

            if isDetected, let board = context.board {
                context.neopixel.setupNeopixel(board: board, components: context.components, is400HzEnabled: context.is400HzEnabled) { [weak context] success in
                    guard let context = context else { return }

                    DispatchQueue.main.async { [unowned context] in
                        if success {
                            context.onClickClear(context)
                            //context.neopixel.clearBoard(color: context.currentColor/*context.kDefaultLedColor*/, colorW: context.colorW)
                        }

                        context.updateStatusUI(isWaitingResponse: false)
                    }
                }
            } else {
                DispatchQueue.main.async { [unowned context] in
                    context.updateStatusUI(isWaitingResponse: false)
                }
            }
        }
    }

    @IBAction func onDoubleTapScrollView(_ sender: AnyObject) {
        setDefaultPositionAndScale(animated: true)
    }

    @IBAction func onClickClear(_ sender: AnyObject) {
        for ledView in ledViews {
            ledView.backgroundColor = currentColor
        }
        neopixel.clearBoard(color: currentColor, colorW: colorW)
    }

    @IBAction func onChangeBrightness(_ sender: UISlider) {
        neopixel.setBrighness(sender.value)
    }

    @IBAction func onClickHelp(_ sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.sharedInstance

        let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
        helpViewController.setHelp(localizationManager.localizedString("neopixel_help_text"), title: localizationManager.localizedString("neopixel_help_title"))

/*
        let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpExportViewController") as! HelpExportViewController
        helpViewController.setHelp(localizationManager.localizedString("neopixel_help_text"), title: localizationManager.localizedString("neopixel_help_title"))
        helpViewController.fileTitle = "Neopixel Sketch"

        // Setup file download
        let sketchUrl = Bundle.main.url(forResource: "Neopixel_Arduino", withExtension: "zip")!
        helpViewController.fileURL = sketchUrl
*/
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender

        present(helpNavigationController, animated: true, completion: nil)
    }

    @IBAction func onClickRotate(_ sender: AnyObject) {
        contentRotationAngle += CGFloat.pi/2
        rotationView.transform = CGAffineTransform(rotationAngle: contentRotationAngle)
        setDefaultPositionAndScale(animated: true)
    }
}

// MARK: - UICollectionViewDataSource
extension NeopixelModeViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return defaultPalette.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let reuseIdentifier = "ColorCell"
        let colorCell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) //as! AdminMenuCollectionViewCell

        let colorHex = defaultPalette[indexPath.row]
        if let color = UIColor(css: colorHex) {
            colorCell.backgroundColor = color

            let isSelected = currentColor.isEqual(color)
            colorCell.layer.borderWidth = isSelected ? 4:2
            colorCell.layer.borderColor =  (isSelected ? UIColor.white: color.darker(0.5)).cgColor
        }
        colorCell.layer.cornerRadius = 4
        colorCell.layer.masksToBounds = true

        return colorCell
    }
}

// MARK: - UICollectionViewDelegate
extension NeopixelModeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        DLog("colors selected: \(indexPath.item)")
        let colorHex = defaultPalette[indexPath.row]
        if let color = UIColor(css: colorHex) {
            currentColor = color
            colorW = 0          // All palete colors have w component equal to 0
        }
        
        updatePickerColorButton(isSelected: false)

        collectionView.reloadData()
    }
}

// MARK: - UIScrollViewDelegate
extension NeopixelModeViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return contentView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
    }
}

// MARK: - UIPopoverPresentationControllerDelegate
extension NeopixelModeViewController: UIPopoverPresentationControllerDelegate {

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        // This *forces* a popover to be displayed on the iPhone
        if traitCollection.verticalSizeClass != .compact {
            return .none
        } else {
            return .fullScreen
        }
    }

    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        DLog("selector dismissed")
    }
}

// MARK: - UIPopoverPresentationControllerDelegate
extension NeopixelModeViewController: NeopixelColorPickerViewControllerDelegate {
    func onColorPickerChooseColor(_ color: UIColor, wComponent: Float) {
        currentColor = color
        colorW = wComponent
        updatePickerColorButton(isSelected: true)

        paletteCollection.reloadData()
    }

    fileprivate func updatePickerColorButton(isSelected: Bool) {        // Note: colorW and currentColor should have been set previously
        colorPickerWComponentColorView.backgroundColor = UIColor(red: CGFloat(colorW), green: CGFloat(colorW), blue: CGFloat(colorW), alpha: 1.0)
        colorPickerContainerView.backgroundColor = currentColor
        colorPickerContainerView.layer.borderWidth = isSelected ? 4:2
        colorPickerContainerView.layer.borderColor = (isSelected ? UIColor.white: colorPickerContainerView.backgroundColor?.darker(0.5) ?? .black ).cgColor
    }
}
