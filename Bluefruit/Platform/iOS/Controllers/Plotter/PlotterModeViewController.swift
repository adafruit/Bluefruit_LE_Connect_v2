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

    // UI
    @IBOutlet weak var chartView: LineChartView!
    @IBOutlet weak var autoscrollButton: UISwitch!
    @IBOutlet weak var xMaxEntriesSlider: UISlider!

    // Data
    fileprivate var uartDataManager: UartDataManager!
    fileprivate var originTimestamp: CFAbsoluteTime!
    fileprivate var isAutoScrollEnabled = true
    fileprivate var visibleInterval: TimeInterval = 20      // in seconds
    fileprivate var lineDashForPeripheral = [UUID: [CGFloat]?]()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Init
        uartDataManager = UartDataManager(delegate: self)
        setupChart()
        originTimestamp = CFAbsoluteTimeGetCurrent()

        // Title
        let localizationManager = LocalizationManager.sharedInstance
        let name = blePeripheral?.name ?? localizationManager.localizedString("scanner_unnamed")
        self.title = traitCollection.horizontalSizeClass == .regular ? String(format: localizationManager.localizedString("plotter_navigation_title_format"), arguments: [name]) : localizationManager.localizedString("plotter_tab_title")

        // UI
        autoscrollButton.isOn = isAutoScrollEnabled
        chartView.dragEnabled = !isAutoScrollEnabled
        xMaxEntriesSlider.value = Float(visibleInterval)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Enable Uart
        setupUart()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - UART
    fileprivate func isInMultiUartMode() -> Bool {
        return blePeripheral == nil
    }

    fileprivate func setupUart() {
        // Reset colors assigned to peripherals
        let lineDashes = UartStyle.defaultLineDashes()
        lineDashForPeripheral.removeAll()

        // Enable uart
        if isInMultiUartMode() {            // Multiple peripheral mode
            let blePeripherals = BleManager.sharedInstance.connectedPeripherals()
            for (i, blePeripheral) in blePeripherals.enumerated() {
                lineDashForPeripheral[blePeripheral.identifier] = lineDashes[i % lineDashes.count]
                blePeripheral.uartEnable(uartRxHandler: uartDataManager.rxDataReceived) { [weak self] error in
                    guard let context = self else { return }

                    let peripheralName = blePeripheral.name ?? blePeripheral.identifier.uuidString
                    DispatchQueue.main.async { [unowned context] in
                        guard error == nil else {
                            DLog("Error initializing uart")
                            context.dismiss(animated: true, completion: { [weak self] () -> Void in
                                if let context = self {
                                    showErrorAlert(from: context, title: "Error", message: "Uart protocol can not be initialized for peripheral: \(peripheralName)")

                                    BleManager.sharedInstance.disconnect(from: blePeripheral)
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

                DispatchQueue.main.async { [unowned context] in
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

                    // Done
                    DLog("Uart enabled")
                }
            }
        }
    }

    // MARK: - Line Chart
    fileprivate func setupChart() {

        chartView.delegate = self

        
        chartView.backgroundColor = .white      // Fix for Charts 3.0.3 (overrides the default backgorund color)
        
        chartView.chartDescription?.enabled = false
        //chartView.scaleXEnabled = false
//        chartView.xAxis.setLabelCount(5, force: true)
        chartView.xAxis.granularityEnabled = true
        chartView.xAxis.granularity = 5
        chartView.leftAxis.drawZeroLineEnabled = true
        //chartView.xAxis.drawAxisLineEnabled = true
        //chartView.leftAxis.drawAxisLineEnabled = true

        chartView.setExtraOffsets(left: 10, top: 10, right: 10, bottom: 0)
      // chartView.xAxis.gridLineWidth = 2

        chartView.legend.enabled = false
    }

    fileprivate var dataSetsForPeripheral = [UUID: [LineChartDataSet]]()
    fileprivate var lastDataSetModified: LineChartDataSet?

    fileprivate func addEntry(peripheralIdentifier identifier: UUID, index: Int, value: Double, timestamp: CFAbsoluteTime) {
        let entry = ChartDataEntry(x: timestamp, y: value)
        
        var dataSetExists = false
        if let dataSets = dataSetsForPeripheral[identifier] {
            if index < dataSets.count {
                // Add entry to existing dataset
                let dataSet = dataSets[index]
                let _ = dataSet.addEntry(entry)
                
                dataSetExists = true
            }
        }
        
        if !dataSetExists {
            appendDataset(peripheralIdentifier: identifier, entry: entry, index: index)
            
            let allDataSets = dataSetsForPeripheral.flatMap { $0.1 }
            chartView.data = LineChartData(dataSets: allDataSets)
        }
        
        guard let dataSets = dataSetsForPeripheral[identifier], index < dataSets.count else { return }
        lastDataSetModified = dataSets[index]
    }
    
    fileprivate func notifyDataSetChanged() {
        chartView.data?.notifyDataChanged()
        chartView.notifyDataSetChanged()
        chartView.setVisibleXRangeMaximum(visibleInterval)
        chartView.setVisibleXRangeMinimum(visibleInterval)

        guard let dataSet = lastDataSetModified else { return }

        if isAutoScrollEnabled {
            //let xOffset = Double(dataSet.entryCount) - (context.numEntriesVisible-1)
            let xOffset = (dataSet.values.last?.x ?? 0) - (visibleInterval-1)
            chartView.moveViewToX(xOffset)
        }
    }

    fileprivate func appendDataset(peripheralIdentifier identifier: UUID, entry: ChartDataEntry, index: Int) {
        let dataSet = LineChartDataSet(values: [entry], label: "Values[\(identifier.uuidString) : \(index)]")
        let _ = dataSet.addEntry(entry)

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
        } else {
            dataSetsForPeripheral[identifier] = [dataSet]
        }
    }

    // MARK: - Actions
    @IBAction func onClickHelp(_  sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.sharedInstance
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
    private static let kLineSeparator = Data(bytes: [10])

    func onUartRx(data: Data, peripheralIdentifier identifier: UUID) {
        // DLog("uart rx read (hex): \(hexDescription(data: data))")
        // DLog("uart rx read (utf8): \(String(data: data, encoding: .utf8) ?? "<invalid>")")

        guard let lastSeparatorRange = data.range(of: PlotterModeViewController.kLineSeparator, options: .backwards, in: nil) else { return }

        let subData = data.subdata(in: 0..<lastSeparatorRange.upperBound)
        if let dataString = String(data: subData, encoding: .utf8) {

            let linesStrings = dataString.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n")
            for lineString in linesStrings {

                let currentTimestamp = CFAbsoluteTimeGetCurrent() - originTimestamp
                //   DLog("\tline: \(lineString)")

                let valuesStrings = lineString.components(separatedBy: CharacterSet(charactersIn: ",; \t"))
                var i = 0
                // DLog("values: \(valuesStrings)")
                for valueString in valuesStrings {
                    if let value = Double(valueString) {
                        //DLog("value \(i): \(value)")
                        addEntry(peripheralIdentifier: identifier, index: i, value: value, timestamp: currentTimestamp)
                        i = i+1
                    }
                }
                
                DispatchQueue.main.async { [weak self] in
                    self?.notifyDataSetChanged()
                }
            }
        }

        //let numBytesProcessed = subData.count
        //uartDataManager.removeRxCacheFirst(n: numBytesProcessed, peripheralIdentifier: identifier)

        uartDataManager.removeRxCacheFirst(n: lastSeparatorRange.upperBound+1, peripheralIdentifier: identifier)
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
