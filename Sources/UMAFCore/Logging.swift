//
//  Logging.swift
//  UMAFCore
//
//  Centralized logging setup using swift-log.
//

import Foundation
import Logging

public enum UMAFLog {
  public static let label = "dev.umaf"

  // Create a shared logger instance
  public static var logger: Logger = {
    var log = Logger(label: label)
    // Default to info, can be configured via CLI args later
    log.logLevel = .info
    return log
  }()
}

// Protocol for types to easily access the shared logger
public protocol UMAFLoggable {
  var log: Logger { get }
}

extension UMAFLoggable {
  public var log: Logger { UMAFLog.logger }
}
