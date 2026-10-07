import Darwin
import Foundation

enum DockCommand: Sendable {
    case readPreferences
    case writePosition(DockPosition)
    case reload

    var executable: String {
        switch self {
        case .readPreferences, .writePosition: return "/usr/bin/defaults"
        case .reload: return "/usr/bin/killall"
        }
    }

    var arguments: [String] {
        switch self {
        case .readPreferences:
            return ["export", "com.apple.dock", "-"]
        case .writePosition(let position):
            return ["write", "com.apple.dock", "orientation", "-string", position.rawValue]
        case .reload:
            return ["Dock"]
        }
    }

    var title: String {
        switch self {
        case .readPreferences: return "读取 Dock 偏好"
        case .writePosition: return "修改 Dock 位置"
        case .reload: return "重新加载 Dock"
        }
    }
}

final class CommandRunner: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.autodock.commands", qos: .userInitiated)

    func run(_ command: DockCommand) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try self.execute(command))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func execute(_ command: DockCommand) throws -> Data {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = FileHandle.nullDevice
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "C"
        process.environment = environment

        do {
            try process.run()
        } catch {
            throw CommandError.failed(command.title, nil, error.localizedDescription)
        }

        let timeout = TimeoutFlag()
        let timeoutWork = DispatchWorkItem {
            guard process.isRunning else { return }
            timeout.set()
            process.terminate()
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                if process.isRunning {
                    Darwin.kill(process.processIdentifier, SIGKILL)
                }
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: timeoutWork)

        // 同时排空两个管道，避免较大的偏好输出或错误信息阻塞子进程。
        let errorBuffer = OutputBuffer()
        let errorReader = DispatchGroup()
        errorReader.enter()
        DispatchQueue.global().async {
            errorBuffer.set(errors.fileHandleForReading.readDataToEndOfFile())
            errorReader.leave()
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        errorReader.wait()
        timeoutWork.cancel()

        if timeout.value { throw CommandError.timedOut(command.title) }
        guard process.terminationStatus == 0 else {
            let message = String(data: errorBuffer.value, encoding: .utf8) ?? "系统未提供错误说明"
            throw CommandError.failed(command.title, process.terminationStatus, String(message.prefix(2000)))
        }
        return data
    }
}

private final class TimeoutFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = false

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func set() {
        lock.lock()
        storage = true
        lock.unlock()
    }
}

private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var value: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func set(_ data: Data) {
        lock.lock()
        storage = data
        lock.unlock()
    }
}

enum CommandError: LocalizedError {
    case failed(String, Int32?, String)
    case timedOut(String)

    var errorDescription: String? {
        switch self {
        case .failed(let operation, let code, let message):
            let suffix = code.map { "（退出码 \($0)）" } ?? ""
            return "\(operation)失败\(suffix)：\(message)"
        case .timedOut(let operation):
            return "\(operation)超过 5 秒未完成，已停止命令。请手动重试。"
        }
    }
}
