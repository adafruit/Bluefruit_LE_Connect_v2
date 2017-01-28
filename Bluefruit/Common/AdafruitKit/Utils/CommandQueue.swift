//
//  ElementQueue.swift
//  NewtManager
//
//  Created by Antonio García on 17/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

// Command array, executed sequencially
class CommandQueue<Element> {
    var executeHandler: ((_ command: Element)->())?
    
    fileprivate var queueLock = NSLock()
    
    fileprivate var queue = [Element]() {
        didSet {
            var shouldExecute = false
            queueLock.lock()
            // Start executing the first command (if it was not already executing)
            let nextCommand = queue.first
            if oldValue.isEmpty, nextCommand != nil {
                shouldExecute = true
            }
            queueLock.unlock()
            
            if shouldExecute {
                self.executeHandler?(nextCommand!)
            }
        }
    }

    
    func first() -> Element? {
        queueLock.lock() ; defer { queueLock.unlock() }
        return queue.first
    }
    
    func append(_ command: Element) {
        queue.append(command)
    }

    func next() {
        guard !queue.isEmpty else { return }
        
        // Delete finished command and trigger next execution if needed
        queue.removeFirst()
        
        if let nextCommand = queue.first {
            executeHandler?(nextCommand)
        }
    }
    
    func removeAll() {
        queue.removeAll()
        
    }
    
}
