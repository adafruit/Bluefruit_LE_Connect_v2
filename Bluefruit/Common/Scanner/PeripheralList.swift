//
//  PeripheralList.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 05/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

class PeripheralList {
    //
    var filterName: String? = Preferences.scanFilterName {
        didSet {
            Preferences.scanFilterName = filterName
            isFilterDirty = true
        }
    }
    var isFilterNameExact = Preferences.scanFilterIsNameExact {
        didSet {
            Preferences.scanFilterIsNameExact = isFilterNameExact
            isFilterDirty = true
            
        }
    }
    var isFilterNameCaseInsensitive = Preferences.scanFilterIsNameCaseInsensitive {
        didSet {
            Preferences.scanFilterIsNameCaseInsensitive = isFilterNameCaseInsensitive
            isFilterDirty = true
        }
    }
    var rssiFilterValue: Int? = Preferences.scanFilterRssiValue {
        didSet {
            Preferences.scanFilterRssiValue = rssiFilterValue
            isFilterDirty = true
        }
    }
    var isUnnamedEnabled = Preferences.scanFilterIsUnnamedEnabled {
        didSet {
            Preferences.scanFilterIsUnnamedEnabled = isUnnamedEnabled
            isFilterDirty = true
        }
    }
    var isOnlyUartEnabled = Preferences.scanFilterIsOnlyWithUartEnabled {
        didSet {
            Preferences.scanFilterIsOnlyWithUartEnabled = isOnlyUartEnabled
            isFilterDirty = true
        }
    }
    
    private var isFilterDirty = true
    private var peripherals = [BlePeripheral]()
    private var cachedFilteredPeripherals: [BlePeripheral] = []
    
    func setDefaultFilters() {
        filterName = nil
        isFilterNameExact = false
        isFilterNameCaseInsensitive = true
        rssiFilterValue = nil
        isUnnamedEnabled = true
        isOnlyUartEnabled = false
    }
    
    func isAnyFilterEnabled() -> Bool {
        return (filterName != nil && !filterName!.isEmpty) || rssiFilterValue != nil || isOnlyUartEnabled || !isUnnamedEnabled
    }
    
    func filteredPeripherals(forceUpdate: Bool) -> [BlePeripheral] {
        if isFilterDirty || forceUpdate {
            cachedFilteredPeripherals = calculateFilteredPeripherals()
            isFilterDirty = false
        }
        return cachedFilteredPeripherals
    }
    
    func clear() {
        peripherals = [BlePeripheral]()
    }
    
    private func calculateFilteredPeripherals() -> [BlePeripheral] {
        let kUnnamedSortingString = "~~~"       // Unnamed devices go to the bottom
        var peripherals = BleManager.sharedInstance.peripherals().sorted(by: {$0.name ?? kUnnamedSortingString < $1.name ?? kUnnamedSortingString})
        
        // Apply filters
        if isOnlyUartEnabled {
            peripherals = peripherals.filter({$0.isUartAdvertised()})
        }
    
        if !isUnnamedEnabled {
            peripherals = peripherals.filter({$0.name != nil})
        }
        
        if let filterName = filterName, !filterName.isEmpty {
            peripherals = peripherals.filter({ peripheral -> Bool in
                if let name = peripheral.name {
                    let compareOptions = isFilterNameCaseInsensitive ? String.CompareOptions.caseInsensitive: String.CompareOptions()
                    if isFilterNameExact {
                        return name.compare(filterName, options: compareOptions, range: nil, locale: nil) == .orderedSame
                    }
                    else {
                        return name.range(of: filterName, options: compareOptions, range: nil, locale: nil) != nil
                    }
                }
                else {
                    return false
                }
            })
        }
        
        if let rssiFilterValue = rssiFilterValue {
            peripherals = peripherals.filter({ peripheral -> Bool in
                if let rssi = peripheral.rssi {
                    let validRssi = rssi >= rssiFilterValue
                    return validRssi
                }
                else {
                    return false
                }
            })
        }
        
        return peripherals
    }
    
    func filtersDescription() -> String? {
        var filtersTitle: String?
        if let filterName = filterName, !filterName.isEmpty {
            filtersTitle = filterName
        }
        
        if let rssiFilterValue = rssiFilterValue {
            let rssiString = "Rssi >= \(rssiFilterValue)"
            if filtersTitle != nil && !filtersTitle!.isEmpty {
                filtersTitle!.append(", \(rssiString)")
            }
            else {
                filtersTitle = rssiString
            }
        }
        
        if !isUnnamedEnabled {
            let namedString = "with name"
            if filtersTitle != nil && !filtersTitle!.isEmpty {
                filtersTitle!.append(", \(namedString)")
            }
            else {
                filtersTitle = namedString
            }
        }
        
        if isOnlyUartEnabled {
            let uartString = "with UART"
            if filtersTitle != nil && !filtersTitle!.isEmpty {
                filtersTitle!.append(", \(uartString)")
            }
            else {
                filtersTitle = uartString
            }
        }
        
        return filtersTitle
    }
}
