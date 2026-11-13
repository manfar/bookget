import AppKit
import Combine
import Foundation
import SwiftUI

@main
struct BookgetMacApp: App {
    var body: some Scene {
        WindowGroup("Bookget") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @StateObject private var model = DownloadModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bookget")
                        .font(.largeTitle.weight(.semibold))
                    Text("数字古籍下载工具 · Intel Mac")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(model.status)
                    .font(.callout)
                    .foregroundStyle(model.isRunning ? .blue : .secondary)
            }

            Form {
                Section("下载任务") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("下载网址")
                        TextField("https://…", text: $model.url)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("保存目录")
                            .frame(width: 90, alignment: .leading)
                        TextField("下载文件保存位置", text: $model.destinationDirectory)
                            .textFieldStyle(.roundedBorder)
                        Button("选择…", action: model.chooseDestinationDirectory)
                    }

                    HStack {
                        Text("Cookies")
                            .frame(width: 90, alignment: .leading)
                        TextField("可选：选择 Bookget 支持的 Cookie 文件", text: $model.cookiesFile)
                            .textFieldStyle(.roundedBorder)
                        Button("选择…", action: model.chooseCookiesFile)
                    }

                    HStack {
                        Text("Headers")
                            .frame(width: 90, alignment: .leading)
                        TextField("可选：每行一个 Header: Value", text: $model.headersFile)
                            .textFieldStyle(.roundedBorder)
                        Button("选择…", action: model.chooseHeadersFile)
                    }
                }

                Section("下载选项") {
                    HStack {
                        Text("页码范围")
                            .frame(width: 90, alignment: .leading)
                        TextField("例如 4:434；留空为默认", text: $model.sequence)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("册数范围")
                            .frame(width: 90, alignment: .leading)
                        TextField("例如 10:20；留空为默认", text: $model.volume)
                            .textFieldStyle(.roundedBorder)
                    }
                    Stepper(value: $model.threads, in: 1...64) {
                        Text("每任务线程数：\(model.threads)")
                    }
                }
            }
            .formStyle(.grouped)

            GroupBox("运行日志") {
                TextEditor(text: .constant(model.logText))
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 180)
                    .disabled(true)
                    .textEditorStyle(.plain)
            }

            if model.isRunning {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("下载进程正在运行。当前 Go CLI 没有结构化字节进度接口，因此这里不显示虚假的百分比。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("说明：进程退出后请检查日志确认下载结果。终止进程可能留下部分已下载文件。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("开始下载", action: model.startDownload)
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canStart)

                Button("终止进程", role: .destructive, action: model.terminateDownload)
                    .disabled(!model.isRunning)

                Button("打开保存目录", action: model.openDestinationDirectory)
                    .disabled(!model.destinationExists)

                Spacer()
            }
        }
        .padding(18)
        .frame(minWidth: 780, minHeight: 700)
    }
}

final class DownloadModel: ObservableObject {
    @Published var url = ""
    @Published var destinationDirectory = (NSHomeDirectory() as NSString).appendingPathComponent("Downloads/Bookget")
    @Published var cookiesFile = ""
    @Published var headersFile = ""
    @Published var sequence = ""
    @Published var volume = ""
    @Published var threads = 1
    @Published var status = "就绪"
    @Published var logText = ""
    @Published var isRunning = false

    private var process: Process?
    private var isTerminating = false

    var canStart: Bool {
        guard !isRunning else { return false }
        let value = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              components.host != nil else {
            return false
        }
        return !destinationDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var destinationExists: Bool {
        var isDirectory: ObjCBool = false
        let path = expandedPath(destinationDirectory)
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    func chooseDestinationDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择下载保存目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let selected = panel.url {
            destinationDirectory = selected.path
        }
    }

    func chooseCookiesFile() {
        if let selected = chooseFile(title: "选择 Cookies 文件") {
            cookiesFile = selected.path
        }
    }

    func chooseHeadersFile() {
        if let selected = chooseFile(title: "选择 Headers 文件") {
            headersFile = selected.path
        }
    }

    private func chooseFile(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    func startDownload() {
        guard canStart else {
            status = "请填写有效的 HTTP/HTTPS 下载网址和保存目录"
            return
        }

        let fileManager = FileManager.default
        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Bookget", isDirectory: true)
        let destination = URL(fileURLWithPath: expandedPath(destinationDirectory), isDirectory: true)

        do {
            try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

            let emptyCookies = supportDirectory.appendingPathComponent("empty-cookies.txt")
            let emptyHeaders = supportDirectory.appendingPathComponent("empty-headers.txt")
            try createEmptyFileIfNeeded(at: emptyCookies, fileManager: fileManager)
            try createEmptyFileIfNeeded(at: emptyHeaders, fileManager: fileManager)

            guard let resources = Bundle.main.resourceURL else {
                throw AppError.message("应用资源目录不存在")
            }
            let executable = resources.appendingPathComponent("bin/bookget")
            guard fileManager.isExecutableFile(atPath: executable.path) else {
                throw AppError.message("未找到内嵌的 Intel Go 下载程序：\(executable.path)。请重新构建 App。")
            }

            let cookiesPath = cookiesFile.isEmpty ? emptyCookies.path : expandedPath(cookiesFile)
            let headersPath = headersFile.isEmpty ? emptyHeaders.path : expandedPath(headersFile)
            if !fileManager.fileExists(atPath: cookiesPath) {
                throw AppError.message("Cookies 文件不存在：\(cookiesPath)")
            }
            if !fileManager.fileExists(atPath: headersPath) {
                throw AppError.message("Headers 文件不存在：\(headersPath)")
            }

            var arguments = [
                "--input", url.trimmingCharacters(in: .whitespacesAndNewlines),
                "--dir", destination.path,
                "--threads", String(threads),
                "--cookies", cookiesPath,
                "--headers", headersPath
            ]
            let pageRange = sequence.trimmingCharacters(in: .whitespacesAndNewlines)
            let volumeRange = volume.trimmingCharacters(in: .whitespacesAndNewlines)
            if !pageRange.isEmpty {
                arguments += ["--sequence", pageRange]
            }
            if !volumeRange.isEmpty {
                arguments += ["--volume", volumeRange]
            }

            let child = Process()
            child.executableURL = executable
            child.arguments = arguments
            child.currentDirectoryURL = supportDirectory
            child.standardInput = FileHandle.nullDevice

            let outputPipe = Pipe()
            child.standardOutput = outputPipe
            child.standardError = outputPipe

            outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    handle.readabilityHandler = nil
                    return
                }
                let chunk = String(decoding: data, as: UTF8.self)
                DispatchQueue.main.async { [weak self] in
                    self?.appendLog(chunk)
                }
            }

            child.terminationHandler = { [weak self] terminatedProcess in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.isRunning = false
                    let code = terminatedProcess.terminationStatus
                    if self.isTerminating {
                        self.status = "进程已终止（退出码 \(code)；请检查是否有部分文件）"
                        self.appendLog("\n[Bookget GUI] 进程已终止，退出码：\(code)\n")
                    } else if code == 0 {
                        self.status = "进程已退出（退出码 0；请核对日志中的下载结果）"
                        self.appendLog("\n[Bookget GUI] 进程退出，退出码：0\n")
                    } else {
                        self.status = "进程异常退出（退出码 \(code)）"
                        self.appendLog("\n[Bookget GUI] 进程异常退出，退出码：\(code)\n")
                    }
                    self.process = nil
                    self.isTerminating = false
                }
            }

            logText = ""
            appendLog("[Bookget GUI] 启动下载进程\n")
            appendLog("[Bookget GUI] 保存目录：\(destination.path)\n\n")
            try child.run()
            process = child
            isRunning = true
            status = "下载进程运行中"
        } catch {
            status = "启动失败：\(error.localizedDescription)"
            appendLog("\n[Bookget GUI] \(error.localizedDescription)\n")
        }
    }

    func terminateDownload() {
        guard let process, process.isRunning else { return }
        isTerminating = true
        status = "正在终止下载进程…"
        appendLog("\n[Bookget GUI] 已请求终止进程；当前 CLI 不保证优雅取消。\n")
        process.terminate()
    }

    func openDestinationDirectory() {
        let url = URL(fileURLWithPath: expandedPath(destinationDirectory), isDirectory: true)
        NSWorkspace.shared.open(url)
    }

    private func appendLog(_ text: String) {
        let combined = logText + text
        if combined.utf8.count > 300_000 {
            logText = String(combined.suffix(100_000))
        } else {
            logText = combined
        }
    }

    private func expandedPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    private func createEmptyFileIfNeeded(at url: URL, fileManager: FileManager) throws {
        guard !fileManager.fileExists(atPath: url.path) else { return }
        guard fileManager.createFile(atPath: url.path, contents: Data(), attributes: nil) else {
            throw AppError.message("无法创建配置占位文件：\(url.path)")
        }
    }
}

enum AppError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}
