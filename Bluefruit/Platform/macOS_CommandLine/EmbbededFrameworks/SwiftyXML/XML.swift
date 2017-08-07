//  SwiftyXML.swift
//
//  Copyright (c) 2016 ChenYunGui (陈云贵)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation

public enum XMLSubscriptKey {
    case index(Int)          // such as: 1
    case key(String)         // such as: "childName"
    case keyChain(KeyChain)  // such as: "#childName.childName.@attributeName"
    case attribute(String)   // such as: "@attributeName"
}

public enum XMLError : Error {
    case subscriptFailue(String)
    case initFailue(String)
    case wrongChain(String)
}

public enum XMLSubscriptResult {
    
    case null(String)           // means: null(error: String)
    case xml(XML, String)       // means: xml(xml: XML, path: String)
    case array([XML], String)   // means: xml(xmls: [XML], path: String)
    case string(String, String) // means: string(value: String, path: String)
    
    public subscript(index: Int) -> XMLSubscriptResult {
        return self[XMLSubscriptKey.index(index)]
    }
    
    public subscript(key: String) -> XMLSubscriptResult {
        if let subscripKey = getXMLSubscriptKey(from: key) {
            return self[subscripKey]
        } else {
            return .null("wrong key chain format")
        }
    }
    
    public subscript(key: XMLSubscriptKey) -> XMLSubscriptResult {
        
        func subscriptResult(_ result: XMLSubscriptResult, byIndex index: Int) -> XMLSubscriptResult {
            switch result {
            case .null(_):      return self
            case .string(_, let path):
                return .null(path + ": attribute can not subscript by index: \(index)")
            case .xml(_, let path):
                return .null(path + ": single xml can not subscript by index: \(index)")
            case .array(let xmls, let path):
                if xmls.indices.contains(index) {
                    return .xml(xmls[index], path + "[\(index)]")
                } else {
                    return .null(path + ": index:\(index) out of bounds: \(xmls.indices)")
                }
            }
        }
        
        func subscriptResult(_ result: XMLSubscriptResult, byKey key: String) -> XMLSubscriptResult {
            switch result {
            case .null(_):      return self
            case .string(_, let path):
                return .null(path + ": attribute can not subscript by key: \(key)")
            case .xml(let xml, let path):
                let array = xml.children.filter{ $0.name == key }
                if !array.isEmpty {
                    return .array(array, path + "[\"\(key)\"]")
                } else {
                    return .null(path + ": no such children named: \"\(key)\"")
                }
            case .array(let xmls, let path):
                let result = XMLSubscriptResult.xml(xmls[0], path + "[0]")
                return result[key]
            }
        }
        
        func subscriptResult(_ result: XMLSubscriptResult, byAttribute attribute: String) -> XMLSubscriptResult {
            switch result {
            case .null(_):      return self
            case .string(_, let path):
                return .null(path + ": attribute can not subscript by attribute: \(attribute)")
            case .xml(let xml, let path):
                if let attr = xml.attributes[attribute] {
                    return .string(attr, path + "[\"@\(attribute)\"]")
                } else {
                    return .null(path + ": no such attribute named: \(attribute)")
                }
            case .array(let xmls, let path):
                if let attr = xmls[0].attributes[attribute] {
                    return .string(attr, path + "[0][\"@\(attribute)\"]")
                } else {
                    return .null(path + "[0][\"@\(attribute)\"]" + ": no such attribute named: \(attribute)")
                }
            }
        }
        
        switch key {
        case .index(let index):
            return subscriptResult(self, byIndex: index)
            
        case .key(let key):
            return subscriptResult(self, byKey: key)
            
        case .keyChain(let keyChain):
            var result: XMLSubscriptResult?
            for (i, key) in keyChain.pathComponents.enumerated() {
                if i == 0 {
                    switch key {
                    case .index(let index): result = subscriptResult(self, byIndex: index)
                    case .key(let key):     result = subscriptResult(self, byKey: key)
                    default: fatalError("key chain components never contains other type XMLSubscriptionKey")
                    }
                }
                else {
                    switch key {
                    case .index(let index): result = subscriptResult(result!, byIndex: index)
                    case .key(let key):     result = subscriptResult(result!, byKey: key)
                    default: fatalError("key chain components never contains other type XMLSubscriptionKey")
                    }
                }
            }
            guard let subResult = result else { fatalError("unexception") }
            if let attribute = keyChain.attribute {
                return subscriptResult(subResult, byAttribute: attribute)
            } else {
                return subResult
            }
        case .attribute(let attribute):
            return subscriptResult(self, byAttribute: attribute)
        }
    }
    
    public var xml:XML? {
        do {
            return try self.getXML()
        } catch {
            return nil
        }
    }
    
    public func getXML() throws -> XML {
        switch self {
        case .null(let error):
            throw XMLError.subscriptFailue(error)
        case .string(_, let path):
            throw XMLError.subscriptFailue("can not get XML from attribute, from keyChain: \(path)")
        case .xml(let xml, _): return xml
        case .array(let xmls, _): return xmls[0]
        }
    }
    
    public var xmlList:[XML]? {
        do {
            return try getXMLList()
        } catch {
            return nil
        }
    }
    
    public func getXMLList() throws -> [XML] {
        switch self {
        case .null(let error):
            throw XMLError.subscriptFailue(error)
        case .string(_, let path):
            throw XMLError.subscriptFailue("can not get list from attribute, from keyChain: \(path)")
        case .xml(let xml, _): return [xml]
        case .array(let xmls, _): return xmls
        }
    }
    
    public var error: String {
        switch self {
        case .null(let error):
            return error
        default: return ""
        }
    }
}

public struct KeyChain {
    
    var pathComponents: [XMLSubscriptKey] = []
    var attribute: String?
    
    init?(string: String) {
        guard !string.isEmpty else { return nil }
        
        var string = string
        if string.hasPrefix("#") {
            let index = string.index(string.startIndex, offsetBy: 1)
            string = string.substring(from: index)
        }
        
        let strings = string.components(separatedBy: ".").filter{ !$0.isEmpty }
        for (i, str) in strings.enumerated() {
            if str.hasPrefix("@") {
                if i == strings.count - 1 {
                    let index = str.index(str.startIndex, offsetBy: 1)
                    self.attribute = str.substring(from: index)
                } else {
                    return nil
                }
            } else {
                if let v = UInt(str) {
                    self.pathComponents.append(.index(Int(v)))
                } else {
                    self.pathComponents.append(.key(str))
                }
            }
        }
    }
}

open class XML {
    
    public var name:String
    public var attributes:[String: String] = [:]
    public var value:String?
    public internal(set) var children:[XML] = []
    
    internal weak var parent:XML?
    
    public init(name:String, attributes:[String:Any] = [:], value: Any? = nil) {
        self.name = name
        self.addAttributes(attributes)
        if let value = value {
            self.value = String(describing: value)
        }
    }
    
    private convenience init(xml: XML) {
        self.init(name: xml.name, attributes: xml.attributes, value: xml.value)
        self.addChildren(xml.children)
        self.parent = nil
    }
    
    public convenience init!(data: Data) {
        do {
            let parser = SimpleXMLParser(data: data)
            try parser.parse()
            if let xml = parser.root {
                self.init(xml: xml)
            } else {
                fatalError("xml parser exception")
            }
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    public convenience init!(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            self.init(data: data)
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    public convenience init(named name: String) {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent(name) else {
            fatalError("can not get mainBundle URL")
        }
        self.init(url: url)
    }
    
    public convenience init(string: String, encoding: String.Encoding = .utf8) {
        guard let data = string.data(using: encoding) else {
            fatalError("string encoding failed")
        }
        self.init(data: data)
    }
    
    public subscript(index: Int) -> XMLSubscriptResult {
        return self[XMLSubscriptKey.index(index)]
    }
    
    public subscript(key: String) -> XMLSubscriptResult {
        if let subscripKey = getXMLSubscriptKey(from: key) {
            return self[subscripKey]
        } else {
            return .null("wrong key chain format: \(key)")
        }
    }
    
    public subscript(key: XMLSubscriptKey) -> XMLSubscriptResult {
        switch key {
        case .index(let index):
            if self.children.indices.contains(index) {
                return .xml(self.children[index], "[\(index)]")
            } else {
                let bounds = self.children.indices
                return .null("index:\(index) out of bounds: \(bounds)")
            }
            
        case .key(let key):
            let array = self.children.filter{ $0.name == key }
            if !array.isEmpty {
                return .array(array, "[\"\(key)\"]")
            } else {
                return .null("no such children named: \"\(key)\"")
            }
            
        case .keyChain(let keyChain):
            var result: XMLSubscriptResult?
            for (i, path) in keyChain.pathComponents.enumerated() {
                if i == 0 {
                    result = self[path]
                } else {
                    result = result![path]
                }
            }
            guard let subResult = result else {
                fatalError("")
            }
            if let attribute = keyChain.attribute {
                return subResult[XMLSubscriptKey.attribute(attribute)]
            } else {
                return subResult
            }
            
        case .attribute(let attribute):
            if let attr = self.attributes[attribute] {
                return .string(attr, "[\(attribute)]")
            } else {
                return .null("no such attribute named: \"\(attribute)\"")
            }
        }
    }
    
    public func addAttribute(name:String, value:Any) {
        self.attributes[name] = String(describing: value)
    }
    
    public func addAttributes(_ attributes:[String : Any]) {
        for (key, value) in attributes {
            self.addAttribute(name: key, value: value)
        }
    }
    
    public func addChild(_ xml:XML) {
        guard xml !== self else {
            fatalError("can not add self to xml children list!")
        }
        children.append(xml)
        xml.parent = self
    }
    
    public func addChildren(_ xmls: [XML]) {
        xmls.forEach{ self.addChild($0) }
    }
}

// MARK: - XMLSubscriptResult implements Sequence protocol

public class XMLSubscriptResultIterator : IteratorProtocol {
    
    var xmls:[XML]
    var index:Int = 0
    
    public init(result: XMLSubscriptResult) {
        self.xmls = result.xmlList ?? []
    }
    
    public func next() -> XML? {
        if self.xmls.isEmpty { return nil }
        if self.index >= self.xmls.endIndex { return nil }
        defer { index += 1 }
        return self.xmls[index]
    }
}

extension XMLSubscriptResult : Sequence {
    
    public typealias Iterator = XMLSubscriptResultIterator
    
    public func makeIterator() -> XMLSubscriptResult.Iterator {
        return XMLSubscriptResultIterator(result: self)
    }
}

// MARK: - StringProvider protocol and extensions

public protocol StringProvider {
    var string: String? { get }
}

extension XML : StringProvider {
    public var string: String? {
        return self.value
    }
}

extension XMLSubscriptResult : StringProvider {
    public var string: String? {
        switch self {
        case .null(_):               return nil
        case .string(let string, _): return string
        case .xml(let xml, _):       return xml.value
        case .array(let xmls, _):    return xmls[0].value
        }
    }
}

extension RawRepresentable {
    
    static func initialize(rawValue: RawValue?) throws -> Self {
        if let value = rawValue {
            if let result = Self.init(rawValue: value) {
                return result
            } else {
                throw XMLError.initFailue("[\(Self.self)] init failed with raw value: [\(value)]")
            }
        }
        throw XMLError.initFailue("[\(Self.self)] init failed with nil value")
    }
}

extension StringProvider {
    
    public func `enum`<T>() -> T? where T: RawRepresentable, T.RawValue == String { return try? T.initialize(rawValue: self.string) }
    public func `enum`<T>() -> T? where T: RawRepresentable, T.RawValue == UInt8  { return try? T.initialize(rawValue: self.uInt8)  }
    public func `enum`<T>() -> T? where T: RawRepresentable, T.RawValue == UInt16 { return try? T.initialize(rawValue: self.uInt16) }
    public func `enum`<T>() -> T? where T: RawRepresentable, T.RawValue == UInt32 { return try? T.initialize(rawValue: self.uInt32) }
    public func `enum`<T>() -> T? where T: RawRepresentable, T.RawValue == UInt64 { return try? T.initialize(rawValue: self.uInt64) }
    public func `enum`<T>() -> T? where T: RawRepresentable, T.RawValue == UInt   { return try? T.initialize(rawValue: self.uInt)   }
    public func `enum`<T>() -> T? where T: RawRepresentable, T.RawValue == Int8   { return try? T.initialize(rawValue: self.int8)   }
    public func `enum`<T>() -> T? where T: RawRepresentable, T.RawValue == Int16  { return try? T.initialize(rawValue: self.int16)  }
    public func `enum`<T>() -> T? where T: RawRepresentable, T.RawValue == Int32  { return try? T.initialize(rawValue: self.int32)  }
    public func `enum`<T>() -> T? where T: RawRepresentable, T.RawValue == Int64  { return try? T.initialize(rawValue: self.int64)  }
    public func `enum`<T>() -> T? where T: RawRepresentable, T.RawValue == Int    { return try? T.initialize(rawValue: self.int)    }
    
    public func getEnum<T>() throws -> T where T: RawRepresentable, T.RawValue == String { return try T.initialize(rawValue: self.string) }
    public func getEnum<T>() throws -> T where T: RawRepresentable, T.RawValue == UInt8  { return try T.initialize(rawValue: self.uInt8)  }
    public func getEnum<T>() throws -> T where T: RawRepresentable, T.RawValue == UInt16 { return try T.initialize(rawValue: self.uInt16) }
    public func getEnum<T>() throws -> T where T: RawRepresentable, T.RawValue == UInt32 { return try T.initialize(rawValue: self.uInt32) }
    public func getEnum<T>() throws -> T where T: RawRepresentable, T.RawValue == UInt64 { return try T.initialize(rawValue: self.uInt64) }
    public func getEnum<T>() throws -> T where T: RawRepresentable, T.RawValue == UInt   { return try T.initialize(rawValue: self.uInt)   }
    public func getEnum<T>() throws -> T where T: RawRepresentable, T.RawValue == Int8   { return try T.initialize(rawValue: self.int8)   }
    public func getEnum<T>() throws -> T where T: RawRepresentable, T.RawValue == Int16  { return try T.initialize(rawValue: self.int16)  }
    public func getEnum<T>() throws -> T where T: RawRepresentable, T.RawValue == Int32  { return try T.initialize(rawValue: self.int32)  }
    public func getEnum<T>() throws -> T where T: RawRepresentable, T.RawValue == Int64  { return try T.initialize(rawValue: self.int64)  }
    public func getEnum<T>() throws -> T where T: RawRepresentable, T.RawValue == Int    { return try T.initialize(rawValue: self.int)    }
}

// optional
extension StringProvider {
    
    public var bool: Bool? {
        if let string = self.string { return Bool(string) }
        return nil
    }
    // unsigned integer
    public var uInt8: UInt8? {
        if let string = self.string { return UInt8(string) }
        return nil
    }
    public var uInt16: UInt16? {
        if let string = self.string { return UInt16(string) }
        return nil
    }
    public var uInt32: UInt32? {
        if let string = self.string { return UInt32(string) }
        return nil
    }
    public var uInt64: UInt64? {
        if let string = self.string { return UInt64(string) }
        return nil
    }
    public var uInt: UInt? {
        if let string = self.string { return UInt(string) }
        return nil
    }
    // signed integer
    public var int8: Int8? {
        if let string = self.string { return Int8(string) }
        return nil
    }
    public var int16: Int16? {
        if let string = self.string { return Int16(string) }
        return nil
    }
    public var int32: Int32? {
        if let string = self.string { return Int32(string) }
        return nil
    }
    public var int64: Int64? {
        if let string = self.string { return Int64(string) }
        return nil
    }
    public var int: Int? {
        if let string = self.string { return Int(string) }
        return nil
    }
    // decimal
    public var float: Float? {
        if let string = self.string { return Float(string) }
        return nil
    }
    public var double: Double? {
        if let string = self.string { return Double(string) }
        return nil
    }
}

// non optional
extension StringProvider {
    
    public var boolValue: Bool {
        return bool ?? false
    }
    // unsigned integer
    public var uInt8Value: UInt8 {
        return uInt8 ?? 0
    }
    public var uInt16Value: UInt16 {
        return uInt16 ?? 0
    }
    public var uInt32Value: UInt32 {
        return uInt32 ?? 0
    }
    public var uInt64Value: UInt64 {
        return uInt64 ?? 0
    }
    public var uIntValue: UInt {
        return uInt ?? 0
    }
    // signed integer
    public var int8Value: Int8 {
        return int8 ?? 0
    }
    public var int16Value: Int16 {
        return int16 ?? 0
    }
    public var int32Value: Int32 {
        return int32 ?? 0
    }
    public var int64Value: Int64 {
        return int64 ?? 0
    }
    public var intValue: Int {
        return int ?? 0
    }
    // decimal
    public var floatValue: Float {
        return float ?? 0
    }
    public var doubleValue: Double {
        return double ?? 0
    }
    public var stringValue: String {
        return string ?? ""
    }
}


// MARK: - XML Descriptions

public extension XML {
    
    public var description:String {
        return self.toXMLString()
    }
    
    public func toXMLString() -> String {
        var result = ""
        var depth:Int = 0
        describe(xml: self, depth: &depth, result: &result)
        return result
    }
    
    private func describe(xml: XML, depth:inout Int, result: inout String) {
        if xml.children.isEmpty {
            result += xml.getCombine(numTabs: depth)
        } else {
            result += xml.getStartPart(numTabs: depth)
            depth += 1
            for child in xml.children {
                describe(xml: child, depth: &depth, result: &result)
            }
            depth -= 1
            result += xml.getEndPart(numTabs: depth)
        }
    }
    
    private func getAttributeString() -> String {
        return self.attributes.map{ " \($0)=\"\($1)\"" }.joined()
    }
    
    private func getStartPart(numTabs:Int) -> String {
        return getDescription(numTabs: numTabs, closed: false)
    }
    
    private func getEndPart(numTabs:Int) -> String {
        return String(repeating: "\t", count: numTabs) + "</\(name)>\n"
    }
    
    private func getCombine(numTabs:Int) -> String {
        return self.getDescription(numTabs: numTabs, closed: true)
    }
    
    private func getDescription(numTabs:Int, closed:Bool) -> String {
        var attr = self.getAttributeString()
        attr = attr.isEmpty ? "" : attr + " "
        let tabs = String(repeating: "\t", count: numTabs)
        var valueString: String = ""
        if let v = self.value {
            valueString = v.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if attr.isEmpty {
            switch (closed, self.value) {
            case (true,  .some(_)): return tabs + "<\(name)>\(valueString)</\(name)>\n"
            case (true,  .none):    return tabs + "<\(name) />\n"
            case (false, .some(_)): return tabs + "<\(name)>\(valueString)\n"
            case (false, .none):    return tabs + "<\(name)>\n"
            }
        } else {
            switch (closed, self.value) {
            case (true,  .some(_)): return tabs + "<\(name)" + attr + ">\(valueString)</\(name)>\n"
            case (true,  .none):    return tabs + "<\(name)" + attr + "/>\n"
            case (false, .some(_)): return tabs + "<\(name)" + attr + ">\(valueString)\n"
            case (false, .none):    return tabs + "<\(name)" + attr + ">\n"
            }
        }
    }
}

public class SimpleXMLParser: NSObject, XMLParserDelegate {
    
    public var root:XML?
    public let data:Data
    
    weak var currentElement:XML?
    var parseError:Swift.Error?
    
    deinit {
        self.root = nil
        self.currentElement = nil
        self.parseError = nil
    }
    
    public init(data: Data) {
        self.data = data
        super.init()
    }
    
    public func parse() throws {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false
        parser.parse()
        if let error = parseError {
            throw error
        }
    }
    
    // MARK: - XMLParserDelegate
    @objc public func parser(_ parser: XMLParser,
                             didStartElement elementName: String,
                             namespaceURI: String?,
                             qualifiedName qName: String?,
                             attributes attributeDict: [String : String])
    {
        let element = XML(name: elementName, attributes: attributeDict)
        
        if self.root == nil {
            self.root = element
            self.currentElement = element
        } else {
            self.currentElement?.addChild(element)
            self.currentElement = element
        }
    }
    
    @objc public func parser(_ parser: XMLParser, foundCharacters string: String) {
        
        if let currentValue = self.currentElement?.value {
            self.currentElement?.value = currentValue + string
        } else {
            self.currentElement?.value = string
        }
    }
    
    @objc public func parser(_ parser: XMLParser,
                             didEndElement elementName: String,
                             namespaceURI: String?,
                             qualifiedName qName: String?)
    {
        currentElement = currentElement?.parent
    }
    
    @objc public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Swift.Error) {
        self.parseError = parseError
    }
}

fileprivate func getXMLSubscriptKey(from string: String) -> XMLSubscriptKey? {
    if string.hasPrefix("#") {
        if let keyChain = KeyChain(string: string) {
            return XMLSubscriptKey.keyChain(keyChain)
        } else {
            return nil
        }
    }
    else if string.hasPrefix("@") {
        let index = string.index(string.startIndex, offsetBy: 1)
        let string = string.substring(from: index)
        return XMLSubscriptKey.attribute(string)
    }
    else {
        return XMLSubscriptKey.key(string)
    }
}
