//
//  ElementQueue.swift
//  Bluefruit
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
            let nextElement = queue.first
            if oldValue.isEmpty, nextElement != nil {
                shouldExecute = true
            }
            //DLog("queue size: \(queue.count)")
            queueLock.unlock()
            
            if shouldExecute {
                self.executeHandler?(nextElement!)
            }
        }
    }

    func first() -> Element? {
        queueLock.lock(); defer { queueLock.unlock() }
        return queue.first
    }
    
    func append(_ element: Element) {
        queue.append(element)
    }

    func next() {
        guard !queue.isEmpty else { return }
        
        // Delete finished command and trigger next execution if needed
        queue.removeFirst()
        
        if let nextElement = queue.first {
            executeHandler?(nextElement)
        }
    }
    
    func removeAll() {
        queue.removeAll()
    }
}
