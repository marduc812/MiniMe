import Foundation

@main
enum WorkerEntry {
    @MainActor static func main() {
        _ = ClipboardReadWorker.runIfRequested()
    }
}
