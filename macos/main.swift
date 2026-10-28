import AppKit
import AVFoundation
import Darwin

struct Settings: Codable {
    let engineRoot: String
    let video: String
    let themeIDs: [String]
}
func expand(_ path: String) -> String { (path as NSString).expandingTildeInPath }
func choose(_ ids: [String], previous: String?) -> String? {
    let unique = Array(Set(ids)).sorted()
    let candidates = unique.filter { $0 != previous }
    return (candidates.isEmpty ? unique : candidates).randomElement()
}
func valid(_ settings: Settings) -> Bool {
    !settings.engineRoot.isEmpty && !settings.themeIDs.isEmpty && settings.themeIDs.allSatisfy {
        $0.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$", options: .regularExpression) != nil
    }
}
if CommandLine.arguments.contains("--self-test") {
    precondition(choose([], previous: nil) == nil)
    precondition(choose(["a", "a"], previous: "a") == "a")
    for _ in 0..<100 { precondition(choose(["a", "b"], previous: "a") == "b") }
    precondition(!valid(Settings(engineRoot: "/tmp", video: "", themeIDs: ["../bad"])))
    print("PASS: random selection, deduplication, no repeat, configuration validation")
    exit(0)
}
if let i = CommandLine.arguments.firstIndex(of: "--check-config"), i + 1 < CommandLine.arguments.count {
    do {
        let c = try JSONDecoder().decode(Settings.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[i + 1])))
        guard valid(c) else { throw NSError(domain: "Invalid configuration", code: 1) }
        let fm = FileManager.default
        guard fm.fileExists(atPath: expand(c.engineRoot) + "/scripts/common-macos.sh"),
              fm.fileExists(atPath: expand(c.engineRoot) + "/scripts/switch-theme-macos.sh") else {
            throw NSError(domain: "Install Dream Skin first, or correct engineRoot", code: 1)
        }
        print("Configuration OK")
        exit(0)
    } catch { fputs("\(error)\n", stderr); exit(1) }
}
final class Overlay: NSWindow {
    var skip: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { skip?() } else { super.keyDown(with: event) }
    }
}
final class Launcher: NSObject, NSApplicationDelegate {
    let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CodexDressedLauncher")
    let bundleID = "com.openai.codex"
    var lock: Int32 = -1
    var worker: Process?
    var log: FileHandle?
    var timer: Timer?
    var player: AVPlayer?
    var window: Overlay?
    var observers: [NSObjectProtocol] = []
    var target: NSRunningApplication?
    var animationDone = false
    var workerDone = false
    var animationBegan: Date?
    var began = Date()
    var lastFrame: CGRect?
    var stable = 0
    var settings: Settings?
    func running() -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
    }
    func record(_ value: String) { try? log?.write(contentsOf: Data("\(Date()) \(value)\n".utf8)) }
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            lock = open(root.appendingPathComponent("launch.lock").path, O_CREAT | O_RDWR, 0o600)
            guard lock >= 0, flock(lock, LOCK_EX | LOCK_NB) == 0 else { NSApp.terminate(nil); return }
            if let app = running() {
                app.activate(options: [.activateAllWindows]); NSApp.terminate(nil); return
            }
            let config = try JSONDecoder().decode(Settings.self, from: Data(contentsOf: root.appendingPathComponent("config.json")))
            guard valid(config) else { throw NSError(domain: "Invalid config.json", code: 1) }
            settings = config
            let previous = try? String(contentsOf: root.appendingPathComponent("last-theme.txt"), encoding: .utf8)
            guard let selected = choose(config.themeIDs, previous: previous) else { return }
            let logURL = root.appendingPathComponent("latest-launch.log")
            try Data().write(to: logURL)
            log = try FileHandle(forWritingTo: logURL)
            record("Selected theme \(selected)")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [Bundle.main.resourceURL!.appendingPathComponent("launch-once.sh").path, expand(config.engineRoot), selected]
            process.standardOutput = log; process.standardError = log
            process.terminationHandler = { [weak self] done in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.workerDone = true
                    self.record("Skin operation exit \(done.terminationStatus)")
                    if done.terminationStatus == 0 {
                        try? selected.write(to: self.root.appendingPathComponent("last-theme.txt"), atomically: true, encoding: .utf8)
                        self.finishIfReady()
                    } else if done.terminationStatus == 21 {
                        self.endAnimation(); self.finishIfReady()
                    } else {
                        self.endAnimation()
                        self.alert("皮肤未能确认生效", "客户端不会被自动重启。详情：\(logURL.path)")
                        NSApp.terminate(nil)
                    }
                }
            }
            worker = process
            try process.run()
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.tick() }
        } catch {
            alert("启动失败", error.localizedDescription)
            NSApp.terminate(nil)
        }
    }
    func geometry(_ pid: pid_t) -> CGRect? {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let frames = list.compactMap { item -> CGRect? in
            guard (item[kCGWindowOwnerPID as String] as? Int) == Int(pid),
                  (item[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = item[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds), rect.width >= 350, rect.height >= 250 else { return nil }
            return rect
        }
        guard var rect = frames.max(by: { $0.width * $0.height < $1.width * $1.height }), let screen = NSScreen.screens.first else { return nil }
        rect.origin.y = screen.frame.maxY - rect.maxY
        return rect
    }
    func tick() {
        if animationDone { return }
        if let animationBegan {
            if target?.isTerminated != false || Date().timeIntervalSince(animationBegan) > 30 { endAnimation(); finishIfReady() }
            return
        }
        if Date().timeIntervalSince(began) > 45 { endAnimation(); finishIfReady(); return }
        guard let app = running(), let frame = geometry(app.processIdentifier) else { return }
        stable = frame == lastFrame ? stable + 1 : 1; lastFrame = frame
        guard stable >= 2 else { return }
        target = app
        guard let settings, !settings.video.isEmpty, FileManager.default.fileExists(atPath: expand(settings.video)) else {
            record("Animation skipped: no readable video"); endAnimation(); finishIfReady(); return
        }
        showMovie(frame, url: URL(fileURLWithPath: expand(settings.video)))
    }
    func showMovie(_ frame: CGRect, url: URL) {
        animationBegan = Date()
        let overlay = Overlay(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        overlay.isReleasedWhenClosed = false; overlay.level = .floating
        overlay.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        overlay.backgroundColor = .clear; overlay.isOpaque = false
        let view = NSView(frame: NSRect(origin: .zero, size: frame.size)); view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        view.layer?.cornerRadius = 12; view.layer?.masksToBounds = true
        let item = AVPlayerItem(url: url); let av = AVPlayer(playerItem: item)
        let layer = AVPlayerLayer(player: av); layer.videoGravity = .resizeAspect
        layer.frame = view.bounds; layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer?.addSublayer(layer)
        overlay.contentView = view
        overlay.skip = { [weak self] in self?.endAnimation(); self?.finishIfReady() }
        for name in [Notification.Name.AVPlayerItemDidPlayToEndTime, .AVPlayerItemFailedToPlayToEndTime] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: item, queue: .main) { [weak self] _ in
                self?.endAnimation(); self?.finishIfReady()
            })
        }
        player = av; window = overlay
        overlay.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); av.play()
        record("Animation window \(Int(frame.width))x\(Int(frame.height))")
    }
    func endAnimation() {
        guard !animationDone else { return }
        animationDone = true; player?.pause(); window?.orderOut(nil); window?.close(); window = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }; observers.removeAll()
        target?.activate(options: [.activateAllWindows])
    }
    func finishIfReady() { if workerDone && animationDone { NSApp.terminate(nil) } }
    func alert(_ title: String, _ detail: String) {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = detail
        NSApp.activate(ignoringOtherApps: true); alert.runModal()
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        worker?.isRunning == true ? .terminateCancel : .terminateNow
    }
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate(); player?.pause(); try? log?.close()
        if lock >= 0 { close(lock) }
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let launcher = Launcher(); app.delegate = launcher; app.run()
