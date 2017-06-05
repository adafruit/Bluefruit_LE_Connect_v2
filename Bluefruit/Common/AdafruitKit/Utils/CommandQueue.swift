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
    var executeHandler: ((_ command: Element) -> Void)?

    fileprivate var queueLock = NSLock()

    /*
    fileprivate var queue = [Element]() {
        didSet {
            queueLock.lock()
            var shouldExecute = false
            // Start executing the first command (if it was not already executing)
            let nextElement = queue.first
            if oldValue.isEmpty, nextElement != nil {
                shouldExecute = true
            }
            DLog("queue size: \(queue.count)")
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
        DLog("queue removeAll")
        queue.removeAll()
    }
 */

    fileprivate var queue = [Element]()

    func first() -> Element? {
        queueLock.lock(); defer { queueLock.unlock() }
        return queue.first
    }

    func next() {
        guard !queue.isEmpty else { return }

        queueLock.lock()
        // Delete finished command and trigger next execution if needed
        queue.removeFirst()
        let nextElement = queue.first
        queueLock.unlock()

        if let nextElement = nextElement {
            executeHandler?(nextElement)
        }
    }

    func append(_ element: Element) {
        queueLock.lock()
        let shouldExecute = queue.isEmpty
        queue.append(element)
        queueLock.unlock()

        if shouldExecute {
            executeHandler?(element)
        }
    }

    func removeAll() {
        //DLog("queue removeAll")
        queue.removeAll()
    }

}
