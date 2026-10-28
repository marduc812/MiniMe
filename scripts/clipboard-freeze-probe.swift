import AppKit

final class SlowProvider: NSObject, NSPasteboardItemDataProvider {
    let delay: TimeInterval
    init(delay: TimeInterval = 4) { self.delay = delay }
    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        Thread.sleep(forTimeInterval: delay)
        item.setString("delayed clipboard content", forType: type)
    }
}

@main
struct FreezeProbe {
    @MainActor static func main() throws {
        if ClipboardReadWorker.runIfRequested() { return }
        if CommandLine.arguments.dropFirst().first == "--file" {
            let name = "MiniMeFileProbe-\(UUID().uuidString)"
            let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
            let store = ClipboardStore(directory: directory)
            let board = NSPasteboard(name: .init(name))
            let source = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(name).txt")
            let content = Data("copied file content".utf8)
            try content.write(to: source)
            defer {
                board.releaseGlobally()
                try? FileManager.default.removeItem(at: source)
                try? FileManager.default.removeItem(at: directory)
            }
            let monitor = ClipboardMonitor(store: store, pasteboard: board)
            board.clearContents()
            board.writeObjects([source as NSURL])
            let start = Date()
            var heartbeatDelay: TimeInterval?
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                heartbeatDelay = Date().timeIntervalSince(start)
            }
            var completed = false
            Task { @MainActor in
                await monitor.poll()
                precondition(store.entries.first?.content == .files(paths: [source.path]))
                let readBack = await Task.detached { try? Data(contentsOf: source) }.value
                precondition(readBack == content, "The app must retain access to copied files")
                try? await Task.sleep(nanoseconds: 150_000_000)
                precondition((heartbeatDelay ?? .infinity) < 0.5, "File capture blocked the main queue")
                store.clearAll()
                await store.flush()
                print(String(format: "File capture and access transfer passed; heartbeat %.3fs", heartbeatDelay!))
                completed = true
            }
            while !completed { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
            return
        }
        if CommandLine.arguments.dropFirst().first == "--image" {
            let name = "MiniMeImageProbe-\(UUID().uuidString)"
            let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
            let store = ClipboardStore(directory: directory)
            let board = NSPasteboard(name: .init(name))
            defer {
                board.releaseGlobally()
                try? FileManager.default.removeItem(at: directory)
            }
            let monitor = ClipboardMonitor(store: store, pasteboard: board)
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 6000, pixelsHigh: 4000,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            arc4random_buf(rep.bitmapData!, rep.bytesPerRow * rep.pixelsHigh)
            let image = NSImage(size: NSSize(width: 6000, height: 4000))
            image.addRepresentation(rep)
            board.clearContents()
            board.writeObjects([image])
            let start = Date()
            var heartbeatDelay: TimeInterval?
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                heartbeatDelay = Date().timeIntervalSince(start)
                print(String(format: "Main queue heartbeat scheduled for 0.1s ran after %.3fs", heartbeatDelay!))
            }
            var completed = false
            Task { @MainActor in
                await monitor.poll()
                print(String(format: "24MP image completed after %.3fs; entries=%d", Date().timeIntervalSince(start), store.entries.count))
                // A quick rejection may finish before the scheduled heartbeat.
                try? await Task.sleep(nanoseconds: 150_000_000)
                precondition((heartbeatDelay ?? .infinity) < 0.5, "Image capture blocked the main queue")
                precondition(store.entries.isEmpty, "Oversized image must be rejected")
                await store.flush()
                completed = true
            }
            while !completed { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
            return
        }
        if CommandLine.arguments.count > 1, !CommandLine.arguments[1].hasPrefix("--") {
            let board = NSPasteboard(name: .init(CommandLine.arguments[1]))
            let provider = SlowProvider(delay: CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2])! : 4)
            let item = NSPasteboardItem()
            item.setDataProvider(provider, forTypes: [.string])
            board.clearContents()
            board.writeObjects([item])
            print("ready")
            fflush(stdout)
            withExtendedLifetime(provider) { RunLoop.main.run() }
            return
        }
        let name = "MiniMeFreezeProbe-\(UUID().uuidString)"
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
        let store = ClipboardStore(directory: directory)
        let board = NSPasteboard(name: .init(name))
        let timeoutMode = CommandLine.arguments.contains("--timeout")
        let monitor = ClipboardMonitor(store: store, pasteboard: board,
            reader: ClipboardReadService(timeout: timeoutMode ? 1.5 : 5))
        let provider = Process()
        provider.executableURL = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/ProbeProvider")
        provider.arguments = [name, timeoutMode ? "15" : "4"]
        let ready = Pipe()
        provider.standardOutput = ready
        try provider.run()
        defer {
            provider.terminate()
            provider.waitUntilExit()
            board.releaseGlobally()
            try? FileManager.default.removeItem(at: directory)
        }
        _ = ready.fileHandleForReading.availableData
        let start = Date()
        var heartbeatDelay: TimeInterval?
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            heartbeatDelay = Date().timeIntervalSince(start)
            print(String(format: "Main queue heartbeat scheduled for 0.1s ran after %.3fs", heartbeatDelay!))
        }
        var completed = false
        Task { @MainActor in
            await monitor.poll()
            print(String(format: "Clipboard capture completed after %.3fs; entries=%d", Date().timeIntervalSince(start), store.entries.count))
            if timeoutMode {
                precondition(store.entries.isEmpty, "Timed-out reads must not be saved")
                board.clearContents()
                board.setString("recovered", forType: .string)
                await monitor.poll()
                precondition(store.entries.first?.content == .text("recovered"), "Worker must restart for the next copy")
                print("Worker timeout and restart passed")
            } else {
                precondition(store.entries.first?.content == .text("delayed clipboard content"))
            }
            precondition((heartbeatDelay ?? .infinity) < 0.5, "Clipboard capture blocked the main queue")
            await store.flush()
            completed = true
        }
        while !completed { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
    }
}
