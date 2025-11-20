//
//  Logging.swift
//  UMAF — structured logging wrappers
//

import Foundation
import OSLog

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
