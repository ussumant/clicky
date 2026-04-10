//
//  main.swift
//  clicky-cli
//
//  JSON-first command-line interface for Clicky. Designed for use by
//  coding agents (Claude Code, Codex, etc.) — not for human interactive use.
//
//  Pattern source: Muesli's MuesliCLI (Paperclip adapter pattern).
//
//  Usage:
//    clicky-cli spec                    — show command tree
//    clicky-cli config get              — show current settings
//    clicky-cli config set <key> <val>  — change a setting
//    clicky-cli status                  — show current state
//

import Foundation

// MARK: - JSON Envelope

struct CLIEnvelope: Codable {
    let ok: Bool
    let command: String
    let data: [String: AnyCodable]?
    let error: CLIError?
    let meta: CLIMeta

    struct CLIError: Codable {
        let code: String
        let message: String
        let fix: String?
    }

    struct CLIMeta: Codable {
        let schemaVersion: Int
        let generatedAt: String
    }
}

/// Type-erased Codable wrapper for mixed-type dictionaries.
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) { value = string }
        else if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else { value = "" }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String: try container.encode(string)
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let bool as Bool: try container.encode(bool)
        default: try container.encode(String(describing: value))
        }
    }
}

// MARK: - Helpers

func makeMeta() -> CLIEnvelope.CLIMeta {
    CLIEnvelope.CLIMeta(
        schemaVersion: 1,
        generatedAt: ISO8601DateFormatter().string(from: Date())
    )
}

func emitSuccess(command: String, data: [String: Any]) {
    let codableData = data.mapValues { AnyCodable($0) }
    let envelope = CLIEnvelope(ok: true, command: command, data: codableData, error: nil, meta: makeMeta())
    emit(envelope)
}

func emitFailure(command: String, code: String, message: String, fix: String? = nil) {
    let error = CLIEnvelope.CLIError(code: code, message: message, fix: fix)
    let envelope = CLIEnvelope(ok: false, command: command, data: nil, error: error, meta: makeMeta())
    emit(envelope)
}

func emit(_ envelope: CLIEnvelope) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(envelope) {
        print(String(data: data, encoding: .utf8) ?? "{}")
    }
}

// MARK: - UserDefaults Access

/// Reads Clicky's UserDefaults. Since the CLI runs as a separate process,
/// we access the same domain the main app uses.
let defaults = UserDefaults.standard

let configKeys: [String: (key: String, defaultValue: String)] = [
    "model": ("selectedClaudeModel", "claude-sonnet-4-6"),
    "backend": ("selectedChatBackend", "api"),
    "tts": ("selectedTTSBackend", "cloud"),
    "asr": ("selectedASRBackend", "cloud"),
    "mode": ("selectedInteractionMode", "voice"),
]

// MARK: - Commands

func handleSpec() {
    let commands: [String: Any] = [
        "name": "clicky-cli",
        "version": "1.0.0",
        "description": "JSON CLI for Clicky — AI buddy that lives next to your cursor",
        "commands": [
            "spec": "Show this command tree",
            "status": "Show current state (running, settings, provider info)",
            "config get": "Show all current settings as JSON",
            "config set <key> <value>": "Change a setting. Keys: model, backend, tts, asr, mode",
        ] as [String: String]
    ]
    emitSuccess(command: "clicky-cli spec", data: commands)
}

func handleStatus() {
    let claudeBinary = findClaudeBinary()
    let data: [String: Any] = [
        "model": defaults.string(forKey: "selectedClaudeModel") ?? "claude-sonnet-4-6",
        "backend": defaults.string(forKey: "selectedChatBackend") ?? "api",
        "tts": defaults.string(forKey: "selectedTTSBackend") ?? "cloud",
        "asr": defaults.string(forKey: "selectedASRBackend") ?? "cloud",
        "mode": defaults.string(forKey: "selectedInteractionMode") ?? "voice",
        "claudeCLIAvailable": claudeBinary != nil ? "true" : "false",
        "claudeCLIPath": claudeBinary ?? "not found",
    ]
    emitSuccess(command: "clicky-cli status", data: data)
}

func handleConfigGet() {
    var data: [String: Any] = [:]
    for (name, config) in configKeys {
        data[name] = defaults.string(forKey: config.key) ?? config.defaultValue
    }
    emitSuccess(command: "clicky-cli config get", data: data)
}

func handleConfigSet(key: String, value: String) {
    guard let config = configKeys[key] else {
        emitFailure(
            command: "clicky-cli config set",
            code: "invalid_key",
            message: "Unknown config key: \(key)",
            fix: "Valid keys: \(configKeys.keys.sorted().joined(separator: ", "))"
        )
        exit(4)
    }
    defaults.set(value, forKey: config.key)
    emitSuccess(command: "clicky-cli config set", data: [key: value])
}

func findClaudeBinary() -> String? {
    let candidates = [
        "/usr/local/bin/claude",
        "/opt/homebrew/bin/claude",
        "\(NSHomeDirectory())/.local/bin/claude",
        "\(NSHomeDirectory())/.npm-global/bin/claude",
        "\(NSHomeDirectory())/.claude/local/claude"
    ]
    for path in candidates {
        if FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
    }
    return nil
}

// MARK: - Main

let args = CommandLine.arguments.dropFirst() // Drop executable name
let argList = Array(args)

if argList.isEmpty {
    emitFailure(
        command: "clicky-cli",
        code: "no_command",
        message: "No command provided.",
        fix: "Run `clicky-cli spec` to see available commands."
    )
    exit(1)
}

switch argList[0] {
case "spec":
    handleSpec()

case "status":
    handleStatus()

case "config":
    if argList.count < 2 {
        emitFailure(
            command: "clicky-cli config",
            code: "missing_subcommand",
            message: "Missing subcommand. Use 'get' or 'set'.",
            fix: "Run `clicky-cli config get` or `clicky-cli config set <key> <value>`"
        )
        exit(4)
    }

    switch argList[1] {
    case "get":
        handleConfigGet()
    case "set":
        if argList.count < 4 {
            emitFailure(
                command: "clicky-cli config set",
                code: "missing_args",
                message: "Usage: clicky-cli config set <key> <value>",
                fix: "Valid keys: \(configKeys.keys.sorted().joined(separator: ", "))"
            )
            exit(4)
        }
        handleConfigSet(key: argList[2], value: argList[3])
    default:
        emitFailure(
            command: "clicky-cli config \(argList[1])",
            code: "unknown_subcommand",
            message: "Unknown config subcommand: \(argList[1])",
            fix: "Use 'get' or 'set'"
        )
        exit(4)
    }

default:
    emitFailure(
        command: "clicky-cli \(argList[0])",
        code: "unknown_command",
        message: "Unknown command: \(argList[0])",
        fix: "Run `clicky-cli spec` to see available commands."
    )
    exit(1)
}
