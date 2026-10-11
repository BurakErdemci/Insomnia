import Foundation

/// Failure to lock the screen. `what` is the whole story: which framework or
/// symbol was missing, or what the call returned.
struct ScreenLockError: Error, LocalizedError, Sendable {
    let what: String

    var errorDescription: String? { what }
}

/// Locks the login session so the password is asked on the next wake or lid
/// open. The Mac itself stays awake.
protocol ScreenLocking: Sendable {
    func lockNow() throws
}

/// Calls `SACLockScreenImmediate` from the login framework, the call behind
/// Ctrl+Cmd+Q. This is a private Apple API with no documentation or
/// stability promise: an OS update can rename or remove it. That is why a
/// failure is thrown and shown in the menu instead of being swallowed.
/// Measured on macOS 27.0.1 (M4): with an active session it locks about one
/// second after the lid closes, and the Mac stays awake with the network up.
struct LoginFrameworkScreenLocker: ScreenLocking {
    private static let frameworkPath = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"
    private static let symbolName = "SACLockScreenImmediate"

    private typealias LockScreenImmediate = @convention(c) () -> Int32

    func lockNow() throws {
        guard let handle = dlopen(Self.frameworkPath, RTLD_NOW) else {
            throw ScreenLockError(what: "login.framework could not be loaded")
        }
        guard let pointer = dlsym(handle, Self.symbolName) else {
            throw ScreenLockError(what: "login.framework has no \(Self.symbolName)")
        }
        let lock = unsafeBitCast(pointer, to: LockScreenImmediate.self)
        let status = lock()
        guard status == 0 else {
            throw ScreenLockError(what: "\(Self.symbolName) returned \(status)")
        }
    }
}

/// Does nothing; the default where a test or a caller does not lock.
struct NoopScreenLocker: ScreenLocking {
    func lockNow() throws {}
}
