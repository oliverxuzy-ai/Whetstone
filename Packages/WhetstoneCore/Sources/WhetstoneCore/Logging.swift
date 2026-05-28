import os

/// Shared `os.Logger` instances for the WhetstoneCore package.
/// Callers (app or package) import WhetstoneCore and reference `Log.api`, etc.
/// Categories align with Console.app filter tokens:
///   subsystem = com.zhengyangxu.whetstone | category = api | parse | persistence
public enum Log {
    public static let subsystem = "com.zhengyangxu.whetstone"
    public static let api        = Logger(subsystem: subsystem, category: "api")
    public static let parse      = Logger(subsystem: subsystem, category: "parse")
    public static let persistence = Logger(subsystem: subsystem, category: "persistence")
}
