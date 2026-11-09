import Foundation

/// Debug flags. Use `--key=value`: AppKit treats a bare `--key value` pair as a defaults override,
/// which can stop the main window from opening.
enum CommandLineFlags {
    static func value(_ key: String, in args: [String] = CommandLine.arguments) -> String? {
        if let eq = args.first(where: { $0.hasPrefix(key + "=") }) { return String(eq.dropFirst(key.count + 1)) }
        guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}
