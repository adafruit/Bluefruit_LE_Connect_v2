//
//  NeopixelModuleViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 24/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit
import SSZipArchive

class NeopixelModuleViewController: ModuleViewController {
    
    // Constants
    private var defaultPalette: [String] = []
    private let kLedWidth: CGFloat = 44
    private let kLedHeight: CGFloat = 44
    private let kDefaultLedColor = UIColor(hex: 0xffffff)

    // UI
    @IBOutlet weak var statusView: UIView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var connectButton: UIButton!
    
    @IBOutlet weak var paletteCollection: UICollectionView!
    
    @IBOutlet weak var boardScrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var contentViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentViewHeightConstrait: NSLayoutConstraint!
    
    @IBOutlet weak var colorPickerButton: UIButton!
    @IBOutlet weak var boardControlsView: UIView!
    
    @IBOutlet weak var rotationView: UIView!

    // Data
    private let neopixel = NeopixelModuleManager()
    private var board: NeopixelModuleManager.Board?
    private var ledViews: [UIView] = []
    
    private var currentColor: UIColor = UIColor.redColor()
    private var contentRotationAngle: CGFloat = 0

    private var boardMargin = UIEdgeInsetsZero
    private var boardCenterScrollOffset = CGPointZero
    
    private var isSketchTooltipAlreadyShown = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Init
        neopixel.delegate = self
        board = NeopixelModuleManager.Board.loadStandardBoard(0)
        
        // Read palette from resources
        let path = NSBundle.mainBundle().pathForResource("NeopixelDefaultPalette", ofType: "plist")!
        defaultPalette = NSArray(contentsOfFile: path) as! [String]
        
        // UI
        statusView.layer.borderColor = UIColor.whiteColor().CGColor
        statusView.layer.borderWidth = 1
        
        boardScrollView.layer.borderColor = UIColor.whiteColor().CGColor
        boardScrollView.layer.borderWidth = 1
        
        colorPickerButton.layer.cornerRadius = 4
        colorPickerButton.layer.masksToBounds = true
        
        createBoardUI()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Show tooltip alert
        if Preferences.neopixelIsSketchTooltipEnabled && !isSketchTooltipAlreadyShown{
            let localizationManager = LocalizationManager.sharedInstance
            let alertController = UIAlertController(title: localizationManager.localizedString("dialog_notice"), message: localizationManager.localizedString("neopixel_sketch_tooltip"), preferredStyle: .Alert)
            
            let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .Default, handler:nil)
            alertController.addAction(okAction)
            
            let dontshowAction = UIAlertAction(title: localizationManager.localizedString("dialog_dontshowagain"), style: .Destructive) { (action) in
                Preferences.neopixelIsSketchTooltipEnabled = false
            }
            alertController.addAction(dontshowAction)
            
            self.presentViewController(alertController, animated: true, completion: nil)
            isSketchTooltipAlreadyShown = true
        }
        
        //
        updateStatusUI()
        neopixel.start()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        neopixel.stop()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "boardSelectorSegue"  {
            if let controller = segue.destinationViewController.popoverPresentationController {
                controller.delegate = self
                
                let boardSelectorViewController = segue.destinationViewController as! NeopixelBoardSelectorViewController
                boardSelectorViewController.onClickStandardBoard = { [unowned self] standardBoardIndex in
                    var currentType: UInt16!
                    if let type = self.board?.type {
                        currentType = type
                    }
                    else {
                        currentType = NeopixelModuleManager.kDefaultType
                    }
                    
                    let board = NeopixelModuleManager.Board.loadStandardBoard(standardBoardIndex, type: currentType)
                    self.changeBoard(board)
                }
                
                boardSelectorViewController.onClickCustomLineStrip = { [unowned self] in
                    self.showLineStripDialog()
                    
                }
            }
        }
        else if segue.identifier == "boardTypeSegue" {
            if let controller = segue.destinationViewController.popoverPresentationController {
                controller.delegate = self
                
                let typeSelectorViewController = segue.destinationViewController as! NeopixelTypeSelectorViewController
                
                if let type = board?.type {
                    typeSelectorViewController.currentType = type
                }
                else {
                    typeSelectorViewController.currentType = NeopixelModuleManager.kDefaultType
                }
                
                typeSelectorViewController.onClickSetType = { [unowned self] type in
                    if var board = self.board {
                        board.type = type
                        self.changeBoard(board)
                    }
                }
            }
        }
        else if segue.identifier == "colorPickerSegue"  {
            if let controller = segue.destinationViewController.popoverPresentationController {
                controller.delegate = self
                
                if let colorPickerViewController = segue.destinationViewController as? NeopixelColorPickerViewController {
                    colorPickerViewController.delegate = self
                }
            }
        }
    }
    
    
    /*
    override func willTransitionToTraitCollection(newCollection: UITraitCollection, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransitionToTraitCollection(newCollection, withTransitionCoordinator: coordinator)
        
        createBoardUI()
    }
    */
    
    private func changeBoard(board: NeopixelModuleManager.Board) {
        self.board = board
        createBoardUI()
        neopixel.resetBoard()
        updateStatusUI()
    }
    
    private func showLineStripDialog() {
        // Show dialog
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: nil, message: "Selet line strip length", preferredStyle: .Alert)
        
        let okAction = UIAlertAction(title: "Select", style: .Default) { (_) in
            let stripLengthTextField = alertController.textFields![0] as UITextField
            
            if let text = stripLengthTextField.text, let stripLength = Int(text) {
                let board = NeopixelModuleManager.Board(name: "1x\(stripLength)", width: UInt8(stripLength), height:UInt8(1), components: UInt8(3), stride: UInt8(stripLength), type: NeopixelModuleManager.kDefaultType)
                self.changeBoard(board)
            }
        }
        okAction.enabled = false
        alertController.addAction(okAction)
        
        alertController.addTextFieldWithConfigurationHandler { (textField) -> Void in
            textField.placeholder = "Enter Length"
            textField.keyboardType = .NumberPad
            
            NSNotificationCenter.defaultCenter().addObserverForName(UITextFieldTextDidChangeNotification, object: textField, queue: NSOperationQueue.mainQueue()) { (notification) in
                okAction.enabled = textField.text != ""
            }            
        }
      
        alertController.addAction(UIAlertAction(title: localizationManager.localizedString("dialog_cancel"), style: .Cancel, handler: nil))
        
        self.presentViewController(alertController, animated: true) { () -> Void in
        }
    }

    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        updateBoardPositionValues()
        setDefaultPositionAndScaleAnimated(true)
    }
    
    private func updateStatusUI() {
        connectButton.enabled = neopixel.isSketchDetected != true || (neopixel.isReady() && (neopixel.board == nil && !neopixel.isWaitingResponse))
        
        let isBoardConfigured = neopixel.isBoardConfigured()
        boardScrollView.alpha = isBoardConfigured ? 1.0:0.2
        boardControlsView.alpha = isBoardConfigured ? 1.0:0.2
        
        var statusMessage: String?
        if !neopixel.isReady() {
            statusMessage = "Waiting for Uart..."
        }
        else if neopixel.isSketchDetected == nil {
            statusMessage = "Ready to Connect"
        }
        else if neopixel.isSketchDetected! {
            if neopixel.board == nil {
                if neopixel.isWaitingResponse {
                    statusMessage = "Waiting for Setup"
                }
                else {
                    statusMessage = "Ready to Setup"
                }
            }
            else {
                statusMessage = "Connected"
            }
        }
        else {
            statusMessage = "Not detected"
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
        let ledBorderColor = UIColor.whiteColor().colorWithAlphaComponent(0.2).CGColor
        let ledCircleMargin: CGFloat = 1
        var k = 0
        ledViews = []
        if let board = board {
            boardScrollView.layoutIfNeeded()
            
            updateBoardPositionValues()

            //let boardMargin = UIEdgeInsetsMake(verticalMargin, horizontalMargin, verticalMargin, horizontalMargin)
            
            for j in 0..<board.height {
                for i in 0..<board.width {
                    let button = UIButton(frame: CGRectMake(CGFloat(i)*kLedWidth+boardMargin.left, CGFloat(j)*kLedHeight+boardMargin.top, kLedWidth, kLedHeight))
                    button.layer.borderColor = ledBorderColor
                    button.layer.borderWidth = 1
                    button.tag = k
                    button.addTarget(self, action: #selector(NeopixelModuleViewController.ledPressed(_:)), forControlEvents: [.TouchDown])
                    rotationView.addSubview(button)
                    
                    let colorView = UIView(frame: CGRectMake(ledCircleMargin, ledCircleMargin, kLedWidth-ledCircleMargin*2, kLedHeight-ledCircleMargin*2))
                    colorView.userInteractionEnabled = false
                    colorView.layer.borderColor = ledBorderColor
                    colorView.layer.borderWidth = 2
                    colorView.layer.cornerRadius = kLedWidth/2
                    colorView.layer.masksToBounds = true
                    colorView.backgroundColor = kDefaultLedColor
                    ledViews.append(colorView)
                    button.addSubview(colorView)
                    
                    k += 1
                }
            }

            contentViewWidthConstraint.constant = CGFloat(board.width) * kLedWidth + boardMargin.left + boardMargin.right
            contentViewHeightConstrait.constant = CGFloat(board.height) * kLedHeight + boardMargin.top + boardMargin.bottom
            boardScrollView.minimumZoomScale = 0.1
            boardScrollView.maximumZoomScale = 10
            setDefaultPositionAndScaleAnimated(false)
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
            
            let boardWidthPoints = CGFloat(board.width) * kLedWidth
            let boardHeightPoints = CGFloat(board.height) * kLedHeight
            
            let horizontalMargin = max(0, (boardScrollView.bounds.width - boardWidthPoints)/2)
            let verticalMargin = max(0, (boardScrollView.bounds.height - boardHeightPoints)/2)
            
            boardCenterScrollOffset = CGPointMake(boardMargin.left - horizontalMargin, boardMargin.top - verticalMargin)
        }
    }

    private func setDefaultPositionAndScaleAnimated(animated: Bool) {
        boardScrollView.setZoomScale(1, animated: animated)
        boardScrollView.setContentOffset(boardCenterScrollOffset, animated: animated)
    }
    
    func ledPressed(sender: UIButton) {
        let isBoardConfigured = neopixel.isBoardConfigured()
        if let board = board where isBoardConfigured {
            let x = sender.tag % Int(board.width)
            let y = sender.tag / Int(board.width)
            DLog("led: (\(x)x\(y))")
            
            ledViews[sender.tag].backgroundColor = currentColor
            neopixel.setPixelColor(currentColor, x: UInt8(x), y: UInt8(y))
        }
    }
    
    // MARK: - Actions
    @IBAction func onClickConnect(sender: AnyObject) {
        neopixel.connectNeopixel()
        updateStatusUI()
    }
    
    @IBAction func onDoubleTapScrollView(sender: AnyObject) {
        setDefaultPositionAndScaleAnimated(true)
    }
    
    @IBAction func onClickClear(sender: AnyObject) {
        for ledView in ledViews {
            ledView.backgroundColor = currentColor
        }
        neopixel.clearBoard(currentColor)
    }
    
    @IBAction func onChangeBrightness(sender: UISlider) {
        neopixel.setBrighness(sender.value)
    }
    
    @IBAction func onClickHelp(sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.sharedInstance
        let helpViewController = storyboard!.instantiateViewControllerWithIdentifier("HelpExportViewController") as! HelpExportViewController
        helpViewController.setHelp(localizationManager.localizedString("neopixel_help_text"), title: localizationManager.localizedString("neopixel_help_title"))
        helpViewController.fileTitle = "Neopixel Sketch"
        
        let cacheDirectoryURL =  try! NSFileManager().URLForDirectory(.CachesDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
        if let sketchPath = cacheDirectoryURL.URLByAppendingPathComponent("Neopixel.zip").path {
            
            let isSketchZipAvailable = NSFileManager.defaultManager().fileExistsAtPath(sketchPath)
            
            if !isSketchZipAvailable {
                // Create zip from code if not exists
                if let sketchFolder = NSBundle.mainBundle().pathForResource("Neopixel", ofType: nil) {
                    
                    let result = SSZipArchive.createZipFileAtPath(sketchPath, withContentsOfDirectory: sketchFolder)
                    DLog("Neopiel zip created: \(result)")
                }
                else {
                    DLog("Error creating zip file")
                }
            }
            
            // Setup file download
            helpViewController.fileURL = NSURL(fileURLWithPath: sketchPath)
        }
        
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .Popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender
        
        presentViewController(helpNavigationController, animated: true, completion: nil)
    }

    @IBAction func onClickRotate(sender: AnyObject) {
        contentRotationAngle += CGFloat(M_PI_2)
        rotationView.transform = CGAffineTransformMakeRotation(contentRotationAngle)
        setDefaultPositionAndScaleAnimated(true)
    }
}

// MARK: - UICollectionViewDataSource
extension NeopixelModuleViewController: UICollectionViewDataSource {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return defaultPalette.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let reuseIdentifier = "ColorCell"
        let colorCell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) //as! AdminMenuCollectionViewCell
        
        let colorHex = defaultPalette[indexPath.row]
        let color = UIColor(CSS: colorHex)
        colorCell.backgroundColor = color
        
        let isSelected = currentColor.isEqual(color)
        colorCell.layer.borderWidth = isSelected ? 4:2
        colorCell.layer.borderColor =  (isSelected ? UIColor.whiteColor(): color.darker(0.5)).CGColor
        colorCell.layer.cornerRadius = 4
        colorCell.layer.masksToBounds = true
        
        return colorCell
    }
}

// MARK: - UICollectionViewDelegate
extension NeopixelModuleViewController: UICollectionViewDelegate {
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        DLog("colors selected: \(indexPath.item)")
        let colorHex = defaultPalette[indexPath.row]
        let color = UIColor(CSS: colorHex)
        currentColor = color
        updatePickerColorButton(false)
        
        collectionView.reloadData()
    }
}


// MARK: - UIScrollViewDelegate
extension NeopixelModuleViewController: UIScrollViewDelegate {
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return contentView
    }
    
    func scrollViewDidZoom(scrollView: UIScrollView) {
        //        let zoomScale = scrollView.zoomScale
        //        contentViewWidthConstraint.constant = zoomScale*200
        //        contentViewHeightConstrait.constant = zoomScale*200
    }
}


// MARK: - NeopixelModuleManagerDelegate
extension NeopixelModuleViewController: NeopixelModuleManagerDelegate {
    func onNeopixelSetupFinished(success: Bool) {
        if (success) {
            neopixel.clearBoard(kDefaultLedColor)
        }
        
        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            self.updateStatusUI()
            });
    }
    
    func onNeopixelSketchDetected(detected: Bool) {
        if detected {
            if let board = board {
                neopixel.setupNeopixel(board)
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            self.updateStatusUI()
            });
    }
    
    func onNeopixelUartIsReady() {
        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            self.updateStatusUI()
            });
    }
}

// MARK: - UIPopoverPresentationControllerDelegate
extension NeopixelModuleViewController : UIPopoverPresentationControllerDelegate {
    
    func adaptivePresentationStyleForPresentationController(PC: UIPresentationController) -> UIModalPresentationStyle {
        // This *forces* a popover to be displayed on the iPhone
        if traitCollection.verticalSizeClass != .Compact {
            return .None
        }
        else {
            return .FullScreen
        }
    }
    
    func popoverPresentationControllerDidDismissPopover(popoverPresentationController: UIPopoverPresentationController) {
        DLog("selector dismissed")
    }
}

// MARK: - UIPopoverPresentationControllerDelegate
extension NeopixelModuleViewController : NeopixelColorPickerViewControllerDelegate {
    func onColorPickerChooseColor(color: UIColor) {
        colorPickerButton.backgroundColor = color
        updatePickerColorButton(true)
        currentColor = color
        paletteCollection.reloadData()
    }

    private func updatePickerColorButton(isSelected: Bool) {
        colorPickerButton.layer.borderWidth = isSelected ? 4:2
        colorPickerButton.layer.borderColor =  (isSelected ? UIColor.whiteColor(): colorPickerButton.backgroundColor!.darker(0.5)).CGColor
    }
}