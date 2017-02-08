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
    fileprivate var numEntriesVisible: TimeInterval = 20      // in seconds

    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Init
        assert(blePeripheral != nil)
        uartDataManager = UartDataManager(delegate: self)
        setupChart()
        originTimestamp = CFAbsoluteTimeGetCurrent()

        // Title
        let localizationManager = LocalizationManager.sharedInstance
        let name = blePeripheral?.name ?? localizationManager.localizedString("peripherallist_unnamed")
        let title = String(format: localizationManager.localizedString("plotter_navigation_title_format"), arguments: [name])
        navigationController?.navigationItem.title = title
        
        // UI
        autoscrollButton.isOn = isAutoScrollEnabled
        chartView.dragEnabled = !isAutoScrollEnabled
        xMaxEntriesSlider.value = Float(numEntriesVisible)
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
    
    fileprivate func setupUart() {
        
        blePeripheral?.uartEnable(uartRxHandler: uartDataManager.rxDataReceived) { [weak self] error in
            guard let context = self else {
                return
            }
            
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
    
    // MARK: - Line Chart
    fileprivate func setupChart() {
        
        chartView.delegate = self
        
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
    
    fileprivate func addEntry(index: Int, value: Double, timestamp: CFAbsoluteTime) {
        let entry = ChartDataEntry(x: timestamp, y: value)
        
        DispatchQueue.main.async { [weak self] in
            
            guard let context = self else { return }
            
            if let dataSets = context.chartView.data?.dataSets, index < dataSets.count {
                // Add entry to existing dataset
                let dataSet = dataSets[index]
                let _ = dataSet.addEntry(entry)
                
            }
            else {
                // Create dataset
                let dataSet = LineChartDataSet(values: [entry], label: "Values[\(index)]")
                let _ = dataSet.addEntry(entry)
                
                dataSet.drawCirclesEnabled = false
                dataSet.drawValuesEnabled = false
                dataSet.lineWidth = 2
//                dataSet.setColor(<#T##color: NSUIColor##NSUIColor#>)
                
                if let lineChartData = context.chartView.data {
                    // Append dataset to existing data
                    lineChartData.dataSets.append(dataSet)
                }
                else {
                    // Create data and add first dataset
                    let lineChartData = LineChartData(dataSets: [dataSet])
                    context.chartView.data = lineChartData
                }
            }
            
            guard let dataSets = context.chartView.data?.dataSets, index < dataSets.count, let dataSet = context.chartView.data?.dataSets[index] else { return }
            
            context.chartView.data?.notifyDataChanged()
            context.chartView.notifyDataSetChanged()
            context.chartView.setVisibleXRangeMaximum(context.numEntriesVisible)
            context.chartView.setVisibleXRangeMinimum(context.numEntriesVisible)
            if context.isAutoScrollEnabled {
                let xOffset = Double(dataSet.entryCount) - (context.numEntriesVisible-1)
                context.chartView.moveViewToX(xOffset)
            }
        }
    }

     // MARK: - Actions
    @IBAction func onAutoScrollChanged(_ sender: Any) {
        isAutoScrollEnabled = !isAutoScrollEnabled
        chartView.dragEnabled = !isAutoScrollEnabled
    }
    
    @IBAction func onXScaleValueChanged(_ sender: UISlider) {
        numEntriesVisible = TimeInterval(sender.value)
    }
}

extension PlotterModeViewController: UartDataManagerDelegate {
    private static let kLineSeparator = Data(bytes: [10])
    
    func onUartRx(data: Data) {
        //DLog("uart rx read (hex): \(hexDescription(data: data))")
       // DLog("uart rx read (utf8): \(String(data: data, encoding: .utf8) ?? "<invalid>")")

        guard let lastSeparatorRange = data.range(of: PlotterModeViewController.kLineSeparator, options: .backwards, in: nil) else {
            return
        }
        
        let subData = data.subdata(in: 0..<lastSeparatorRange.upperBound)
        if let dataString = String(data: subData, encoding: .utf8) {
            
            let linesStrings = dataString.components(separatedBy: "\n")
            for lineString in linesStrings {
                
                let currentTimestamp = CFAbsoluteTimeGetCurrent() - originTimestamp
             //   DLog("\tline: \(lineString)")
                
                let valuesStrings = lineString.components(separatedBy: CharacterSet(charactersIn: ", \t"))
                var i = 0
                for valueString in valuesStrings {
                    if let value = Double(valueString) {
                        DLog("value \(i): \(value)")
                        addEntry(index: i, value: value, timestamp: currentTimestamp)
                        i = i+1
                    }
                }
            }
        }
        
        let numBytesProcessed = subData.count
        uartDataManager.removeRxCacheFirst(n: numBytesProcessed)
    }
}

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
