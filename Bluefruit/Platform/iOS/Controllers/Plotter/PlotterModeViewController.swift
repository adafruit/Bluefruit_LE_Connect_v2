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
    fileprivate static let kNumEntriesVisible = 10
    
    // UI
    @IBOutlet weak var chartView: LineChartView!
    
    // Data
    fileprivate var uartPacketManager: UartPacketManager!
    fileprivate var originTimestamp: CFAbsoluteTime!
    fileprivate var isAutoScrollEnabled = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Init
        assert(blePeripheral != nil)
        uartPacketManager = UartPacketManager(delegate: self, isPacketCacheEnabled: false, isMqttEnabled: false)
        setupChart()
        originTimestamp = CFAbsoluteTimeGetCurrent()

        // Title
        let localizationManager = LocalizationManager.sharedInstance
        let name = blePeripheral?.name ?? localizationManager.localizedString("peripherallist_unnamed")
        let title = String(format: localizationManager.localizedString("plotter_navigation_title_format"), arguments: [name])
        navigationController?.navigationItem.title = title
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

        blePeripheral?.uartEnable(uartRxHandler: uartPacketManager.rxPacketReceived) { [weak self] error in
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
      //  chartView.setVisibleXRangeMaximum(10)
//        chartView.setVisibleXRangeMinimum(5)
        chartView.dragEnabled = true
        
        chartView.setExtraOffsets(left: 10, top: 10, right: 10, bottom: 0)
        
        chartView.legend.enabled = false
        
    }

    /*
    private func updateChart() {
        
    }
*/
}

extension PlotterModeViewController: UartPacketManagerDelegate {
    func onUartPacket(_ packet: UartPacket) {
        guard let text = String(data: packet.data, encoding: .utf8) else { return }
        guard let value = Double(text) else { return }
        DLog("data: \(text) \t value: \(value)")
        
        
        
        // Add entry
        let currentTimestamp = packet.timestamp - originTimestamp
        let entry = ChartDataEntry(x: currentTimestamp, y: value)
        
        if let dataSet = chartView.data?.dataSets.first {
            // Add entry to existing dataset
            let _ = dataSet.addEntry(entry)
            
        }
        else {
            // Create dataset
            let dataSet = LineChartDataSet(values: [entry], label: "Values")
            for _ in 0..<PlotterModeViewController.kNumEntriesVisible {
                let _ = dataSet.addEntry(entry)
            }
            
            dataSet.drawCirclesEnabled = false
            dataSet.drawValuesEnabled = false
            dataSet.lineWidth = 2
            let lineChartData = LineChartData(dataSets: [dataSet])
            chartView.data = lineChartData
        }

        guard let dataSet = chartView.data?.dataSets.first else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let context = self else { return }
            
            context.chartView.data?.notifyDataChanged()
            context.chartView.notifyDataSetChanged()
            context.chartView.setVisibleXRangeMaximum(Double(PlotterModeViewController.kNumEntriesVisible))
            if context.isAutoScrollEnabled {
                let xOffset = dataSet.entryCount - (PlotterModeViewController.kNumEntriesVisible-1)
                context.chartView.moveViewToX(Double(xOffset))
            }

        }
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
