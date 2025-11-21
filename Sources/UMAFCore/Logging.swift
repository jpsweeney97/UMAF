//
//  Logging.swift
//  UMAF — structured logging wrappers (Linux compatible)
//

import Foundation

#if canImport(OSLog)
import OSLog
#else
// Minimal shim for Linux where OSLog is unavailable
public struct Logger {
    let label: String
    public init(subsystem: String, category: String) {
        self.label = "[\(category)]"
    }
    
    public func debug(_ msg: String) { print("\(label) DEBUG: \(msg)") }
    public func info(_ msg: String) { print("\(label) INFO: \(msg)") }
    public func notice(_ msg: String) { print("\(label) NOTICE: \(msg)") }
    public func error(_ msg: String) { fputs("\(label) ERROR: \(msg)\n", stderr) }
    public func fault(_ msg: String) { fputs("\(label) FAULT: \(msg)\n", stderr) }
}
#endif

public enum UMAFLog {
    public static let subsystem = "dev.umaf.core"

    public static let core     = Logger(subsystem: subsystem, category: "core")
    public static let cli      = Logger(subsystem: subsystem, category: "cli")
    public static let app      = Logger(subsystem: subsystem, category: "app")
    public static let parsing  = Logger(subsystem: subsystem, category: "parsing")
    public static let io       = Logger(subsystem: subsystem, category: "io")
}

public protocol UMAFLoggable {
    var log: Logger { get }
}

public extension UMAFLoggable {
    var log: Logger { UMAFLog.core }
}
