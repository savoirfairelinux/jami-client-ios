//
//  OSLogDestination.swift
//  Ring
//
//  Created by kateryna on 2020-07-15.
//  Copyright © 2020 Savoir-faire Linux. All rights reserved.
//

import Foundation
import SwiftyBeaver
import os

final class OSLogDestination: BaseDestination {

    fileprivate var level: SwiftyBeaver.Level

    init(level: SwiftyBeaver.Level) {
        self.level = level
    }

    override func send(_ level: SwiftyBeaver.Level,
                       msg: String,
                       thread: String,
                       file: String,
                       function: String,
                       line: Int,
                       context: Any?) -> String? {

        guard level.rawValue >= self.level.rawValue else { return nil}

        let log = self.createOSLog(context: context)

        os_log("%@.%@:%i - \n%{public}@",
               log: log,
               type: self.getOSLogType(from: level),
               file, function, line, msg)
        return super.send(level,
                          msg: msg,
                          thread: thread,
                          file: file,
                          function: function,
                          line: line)
    }
}

private extension OSLogDestination {

    func createOSLog(context: Any?) -> OSLog {
        var currentContext = "Default"
        if let loggerContext = context as? String {
            currentContext = loggerContext
        }
        let subsystem = Bundle.main.bundleIdentifier ?? "Ring"
        let customLog = OSLog(subsystem: subsystem, category: currentContext)
        return customLog
    }

    func getOSLogType(from level: SwiftyBeaver.Level) -> OSLogType {
        var logType: OSLogType
        switch level {
        case .debug:
            logType = .debug
        case .verbose:
            logType = .default
        case .info:
            logType = .info
        case .warning:
            logType = .error
        case .error:
            logType = .fault
        }
        return logType
    }
}
