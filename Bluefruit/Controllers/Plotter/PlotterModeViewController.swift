//
//  PlotterModeViewController.swift
//  Bluefruit
//
//  Created by Antonio on 03/02/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit
import Charts

class PlotterModeViewController: PeripheralModeViewController {
    // Config
    private static let kMaxEntriesPerDataSet = 5000     // Max number of entries per dataset. Older entries will be deteleted
    
    // UI
    @IBOutlet weak var chartView: LineChartView!
    @IBOutlet weak var autoscrollButton: UISwitch!
    @IBOutlet weak var xMaxEntriesSlider: UISlider!
    @IBOutlet weak var autoscrollLabel: UILabel!
    @IBOutlet weak var widthLabel: UILabel!
    
    // Data
    private var uartDataManager: UartDataManager!
    private var originTimestamp: CFAbsoluteTime!
    private var isAutoScrollEnabled = true
    private var visibleInterval: TimeInterval = 20      // in seconds
    private var lineDashForPeripheral = [UUID: [CGFloat]?]()
    private var dataSetsForPeripheral = [UUID: [LineChartDataSet]]()
    private var lastDataSetModified: LineChartDataSet?
    private var valueBufferForPeripheral = [UUID: [[ChartDataEntry]]]()       // For each dataSetForPeripheral there is a valueBuffer that stores the values recevied since the last update. They are all added in one pass to the dataSetForPeripheral before drawing
    //private var chartDataLock = NSLock()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Init
        uartDataManager = UartDataManager(delegate: self, isRxCacheEnabled: true)
        setupChart()
        originTimestamp = CFAbsoluteTimeGetCurrent()

        // Title
        let localizationManager = LocalizationManager.shared
        let name = blePeripheral?.name ?? localizationManager.localizedString("scanner_unnamed")
        self.title = traitCollection.horizontalSizeClass == .regular ? String(format: localizationManager.localizedString("plotter_navigation_title_format"), arguments: [name]) : localizationManager.localizedString("plotter_tab_title")

        // UI
        autoscrollButton.isOn = isAutoScrollEnabled
        chartView.dragEnabled = !isAutoScrollEnabled
        xMaxEntriesSlider.value = Float(visibleInterval)
        
        // Localization
        autoscrollLabel.text = localizationManager.localizedString("plotter_autoscroll")
        widthLabel.text = localizationManager.localizedString("plotter_width")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
//        #if targetEnvironment(macCatalyst)
        // Increase throttle time on macCatalyst to avoid problems
        self.enh_setMinimumNanosecondsBetweenThrottledReloads(UInt64(Double(NSEC_PER_SEC) * 0.5))
//        #endif

        // Enable Uart
        setupUart()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if isMovingFromParent {       // To keep working while the help is displayed
            //       #if targetEnvironment(macCatalyst)
            // Back to default value
            self.enh_setMinimumNanosecondsBetweenThrottledReloads(UInt64(Double(NSEC_PER_SEC) * 0.3))
            //       #endif
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        // Remove old data
        removeOldDataOnMemoryWarning()
    }

    // MARK: - UART
    private func isInMultiUartMode() -> Bool {
        return blePeripheral == nil
    }

    private func setupUart() {
        // Reset line dashes assigned to peripherals
        let lineDashes = UartStyle.defaultLineDashes()
        lineDashForPeripheral.removeAll()

        // Enable uart
        if isInMultiUartMode() {            // Multiple peripheral mode
            let blePeripherals = BleManager.shared.connectedPeripherals()
            for (i, blePeripheral) in blePeripherals.enumerated() {
                lineDashForPeripheral[blePeripheral.identifier] = lineDashes[i % lineDashes.count]
                blePeripheral.uartEnable(uartRxHandler: uartDataManager.rxDataReceived) { [weak self] error in
                    guard let context = self else { return }

                    let peripheralName = blePeripheral.name ?? blePeripheral.identifier.uuidString
                    DispatchQueue.main.async {
                        guard error == nil else {
                            DLog("Error initializing uart")
                            context.dismiss(animated: true, completion: { [weak self] () -> Void in
                                if let context = self {
                                    let localizationManager = LocalizationManager.shared
                                    showErrorAlert(from: context, title: localizationManager.localizedString("dialog_error"), message: String(format: localizationManager.localizedString("uart_error_multipleperiperipheralinit_format"), peripheralName))

                                    BleManager.shared.disconnect(from: blePeripheral)
                                }
                            })
                            return
                        }

                        // Done
                        DLog("Uart enabled for \(peripheralName)")
                    }
                }
            }
        } else if let blePeripheral = blePeripheral {         //  Single peripheral mode
            lineDashForPeripheral[blePeripheral.identifier] = lineDashes.first!
            blePeripheral.uartEnable(uartRxHandler: uartDataManager.rxDataReceived) { [weak self] error in
                guard let context = self else { return }
                
                DispatchQueue.main.async {
                    guard error == nil else {
                        DLog("Error initializing uart")
                        context.dismiss(animated: true, completion: { [weak self] in
                            guard let context = self else { return }
                            let localizationManager = LocalizationManager.shared
                            showErrorAlert(from: context, title: localizationManager.localizedString("dialog_error"), message: localizationManager.localizedString("uart_error_peripheralinit"))
                            
                            if let blePeripheral = context.blePeripheral {
                                BleManager.shared.disconnect(from: blePeripheral)
                            }
                        })
                        return
                    }

                    // Done
                    DLog("Uart enabled")
                }
            }
        }
    }

    // MARK: - Line Chart
    private func setupChart() {
        chartView.delegate = self
        chartView.backgroundColor = .white      // Fix for Charts 3.0.3 (overrides the default background color)

        chartView.chartDescription?.enabled = false
        chartView.xAxis.granularityEnabled = true
        chartView.xAxis.granularity = 5
        chartView.leftAxis.drawZeroLineEnabled = true
        chartView.setExtraOffsets(left: 10, top: 10, right: 10, bottom: 0)
        chartView.legend.enabled = false
        chartView.noDataText = LocalizationManager.shared.localizedString("plotter_nodata")
    }

    private var hasDatasetsCountChanged = false
    
    private func addEntry(peripheralIdentifier identifier: UUID, index: Int, value: Double, timestamp: CFAbsoluteTime) {
        let entry = ChartDataEntry(x: timestamp, y: value)
        
        /*
        if  Config.isDebugEnabled, entry.y < -1 || entry.y > 1 { // Investigating partial values
            DLog("out of bounds")
        }*/
        
        if let valueBuffers = valueBufferForPeripheral[identifier], index < valueBuffers.count {
            // Add entry to existing valueBuffer
            valueBufferForPeripheral[identifier]![index].append(entry)
            /*
            //Debug memory warning
            if dataSet.count > 1000  {
             UIControl().sendAction(Selector(("_performMemoryWarning")), to: UIApplication.shared, for: nil)
             }*/
        }
        else {
            self.appendDataset(peripheralIdentifier: identifier, entry: entry, index: index)
            hasDatasetsCountChanged = true
            /*
             let allDataSets = self.dataSetsForPeripheral.flatMap { $0.1 }
             self.chartView.data = LineChartData(dataSets: allDataSets)      // Note: this internally calls setNeddsUpdate, so it should be called on the main thread
             */
        }
        
        guard let dataSets = dataSetsForPeripheral[identifier], index < dataSets.count else { return}
        lastDataSetModified = dataSets[index]
    }
    
    private func removeOldDataOnMemoryWarning() {
        DLog("removeOldDataOnMemoryWarning")
        for (_, dataSets) in dataSetsForPeripheral {
            for dataSet in dataSets {
                dataSet.removeAll(keepingCapacity: false)
            }
        }
    }
    
    private func notifyDataSetChanged() {
        chartView.data?.notifyDataChanged()
        chartView.notifyDataSetChanged()
        chartView.setVisibleXRangeMaximum(visibleInterval)
        chartView.setVisibleXRangeMinimum(visibleInterval)

        guard let dataSet = lastDataSetModified else { return }

        if isAutoScrollEnabled {
            //let xOffset = Double(dataSet.entryCount) - (context.numEntriesVisible-1)
            let xOffset = (dataSet.entries.last?.x ?? 0) - (visibleInterval-1)
            chartView.moveViewToX(xOffset)
        }
    }

    private func appendDataset(peripheralIdentifier identifier: UUID, entry: ChartDataEntry, index: Int) {
        let dataSet = LineChartDataSet(entries: [entry], label: "Values[\(identifier.uuidString) : \(index)]")
        let _ = dataSet.append(entry)
 
        dataSet.drawCirclesEnabled = false
        dataSet.drawValuesEnabled = false
        dataSet.lineWidth = 2
        let colors = UartStyle.defaultColors()
        let color = colors[index % colors.count]
        dataSet.setColor(color)
        dataSet.lineDashLengths = lineDashForPeripheral[identifier]!
        DLog("color: \(color.hexString()!)")

        if dataSetsForPeripheral[identifier] != nil {
            dataSetsForPeripheral[identifier]!.append(dataSet)
            valueBufferForPeripheral[identifier]!.append([])
        } else {
            dataSetsForPeripheral[identifier] = [dataSet]
            valueBufferForPeripheral[identifier] = [[]]
        }
    }

    // MARK: - Actions
    @IBAction func onClickHelp(_  sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.shared
        let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
        helpViewController.setHelp(localizationManager.localizedString("plotter_help_text"), title: localizationManager.localizedString("plotter_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender

        present(helpNavigationController, animated: true, completion: nil)
    }

    @IBAction func onAutoScrollChanged(_ sender: Any) {
        isAutoScrollEnabled = !isAutoScrollEnabled
        chartView.dragEnabled = !isAutoScrollEnabled
        notifyDataSetChanged()
    }

    @IBAction func onXScaleValueChanged(_ sender: UISlider) {
        visibleInterval = TimeInterval(sender.value)
        notifyDataSetChanged()
    }
}

// MARK: - UartDataManagerDelegate
extension PlotterModeViewController: UartDataManagerDelegate {
    private static let kLineSeparator = Data([10])
    
    func onUartRx(data: Data, peripheralIdentifier identifier: UUID) {
        // DLog("uart rx read (hex): \(hexDescription(data: data))")
        // DLog("uart rx read (utf8): \(String(data: data, encoding: .utf8) ?? "<invalid>")")
        
//        chartDataLock.lock(); defer {chartDataLock.unlock()}
        guard let lastSeparatorRange = data.range(of: PlotterModeViewController.kLineSeparator, options: [.anchored, .backwards], in: nil) else { return }
        
        var isEntryAdded = false
        let secondToLastSeparatorRange = data.range(of: PlotterModeViewController.kLineSeparator, options: [.anchored, .backwards], in: 0..<lastSeparatorRange.lowerBound)
        let from = secondToLastSeparatorRange?.upperBound ?? 0
        let subData = data.subdata(in: from..<lastSeparatorRange.lowerBound)
        
        if let dataString = String(data: subData, encoding: .utf8) {
            let currentTimestamp = CFAbsoluteTimeGetCurrent() - originTimestamp
            let linesStrings = dataString.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n")
            
            
            if let lineString = linesStrings.last {     // Only take into account the lastest one, because the timestamp for all of them will be considered the same one
            //for lineString in linesStrings {
                //   DLog("\tline: \(lineString)")
                let valuesStrings = lineString.components(separatedBy: CharacterSet(charactersIn: ",; \t"))
                var i = 0
                // DLog("values: \(valuesStrings)")
                for valueString in valuesStrings {
                    if let value = Double(valueString) {
                        //DLog("value \(i): \(value)")
                        self.addEntry(peripheralIdentifier: identifier, index: i, value: value, timestamp: currentTimestamp)
                        i = i+1
                        isEntryAdded = true
                    }
                }
            }
        }
        
        if isEntryAdded {
            self.enh_throttledReloadData()      // it will call self.reloadData without overloading the main thread with calls
        }
        
        //let numBytesProcessed = subData.count
        //uartDataManager.removeRxCacheFirst(n: numBytesProcessed, peripheralIdentifier: identifier)

        uartDataManager.removeRxCacheFirst(n: lastSeparatorRange.upperBound, peripheralIdentifier: identifier)
    }
    
    @objc func reloadData() {
        
        //DLog("reloadData")
        DispatchQueue.main.async {
//            self.chartDataLock.lock(); defer {self.chartDataLock.unlock() }

            if self.hasDatasetsCountChanged {
                let allDataSets = self.dataSetsForPeripheral.flatMap { $0.1 }
                self.chartView.data = LineChartData(dataSets: allDataSets)      // Note: this internally calls setNeddsUpdate, so it should be called on the main thread
                self.hasDatasetsCountChanged = false
            }
            else {
                
                var newValueBuffers = [UUID: [[ChartDataEntry]]]()
                for valueBuffers in self.valueBufferForPeripheral {
                    //DLog("unprocessed entries \(valueBuffers.key): \(valueBuffers.value.flatMap({$0}).count)")

                    let dataSets = self.dataSetsForPeripheral[valueBuffers.key]!
                    
                    for i in 0..<valueBuffers.value.count {
                        let valueBuffer  = valueBuffers.value[i]
                        let dataSet = dataSets[i]
                        
                        if dataSet.count + valueBuffer.count > PlotterModeViewController.kMaxEntriesPerDataSet {
                            let elementsToRemove = -(PlotterModeViewController.kMaxEntriesPerDataSet - (dataSet.count + valueBuffer.count))
                            dataSet.removeFirst(elementsToRemove)
                        }
                        
                        for entry in valueBuffer {
                            dataSet.append(entry)
                        }
                    }
                    
                    newValueBuffers[valueBuffers.key] = Array(repeating: [], count: valueBuffers.value.count)
                }
                
                self.valueBufferForPeripheral = newValueBuffers
                self.notifyDataSetChanged()
            }
        }
    }
}

// MARK: - ChartViewDelegate
extension PlotterModeViewController: ChartViewDelegate {

    /*
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        
    }
    
    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        
    }
    
    func chartScaled(_ chartView: ChartViewBase, scaleX: CGFloat, scaleY: CGFloat) {
        
    }
    
    func chartTranslated(_ chartView: ChartViewBase, dX: CGFloat, dY: CGFloat) {
        
    }
 */
}
