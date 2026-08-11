import Foundation

// UserDefaults is Foundation's thread-safe preference store, and MacParakeet
// intentionally injects isolated suites across app, CLI, and test boundaries.
#if compiler(>=6.0)
extension UserDefaults: @unchecked @retroactive Sendable {}
#else
extension UserDefaults: @unchecked Sendable {}
#endif
