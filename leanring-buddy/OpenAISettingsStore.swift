//
//  OpenAISettingsStore.swift
//  leanring-buddy
//
//  Stores user-provided OpenAI configuration. API keys live in Keychain;
//  non-secret voice preferences live in UserDefaults.
//

import Foundation
import Security

enum OpenAISettingsStoreError: LocalizedError {
    case keychainSaveFailed(OSStatus)
    case keychainDeleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .keychainSaveFailed(let status):
            return "Could not save OpenAI API key to Keychain (\(status))."
        case .keychainDeleteFailed(let status):
            return "Could not remove OpenAI API key from Keychain (\(status))."
        }
    }
}

enum OpenAISettingsStore {
    private static let service = "com.learningbuddy.openai"
    private static let apiKeyAccount = "api-key"
    private static let ttsModelUserDefaultsKey = "openAITTSModel"
    private static let ttsVoiceUserDefaultsKey = "openAITTSVoice"
    private static let ttsInstructionsUserDefaultsKey = "openAITTSInstructions"

    static let defaultTTSModel = "gpt-4o-mini-tts"
    static let defaultTTSVoice = "alloy"
    static let defaultTTSInstructions = "speak like a warm, concise pixel-cat coding companion"

    static var apiKey: String? {
        guard let keychainAPIKey = readAPIKeyFromKeychain() else {
            return AppBundleConfiguration.stringValue(forKey: "OpenAIAPIKey")
        }
        return keychainAPIKey
    }

    static var hasAPIKey: Bool {
        apiKey != nil
    }

    static var maskedAPIKeyDescription: String? {
        guard let apiKey else { return nil }
        let suffix = String(apiKey.suffix(4))
        return "saved, ending in \(suffix)"
    }

    static var ttsModel: String {
        get {
            UserDefaults.standard.string(forKey: ttsModelUserDefaultsKey) ?? defaultTTSModel
        }
        set {
            let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmedValue.isEmpty ? defaultTTSModel : trimmedValue, forKey: ttsModelUserDefaultsKey)
        }
    }

    static var ttsVoice: String {
        get {
            UserDefaults.standard.string(forKey: ttsVoiceUserDefaultsKey) ?? defaultTTSVoice
        }
        set {
            let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmedValue.isEmpty ? defaultTTSVoice : trimmedValue, forKey: ttsVoiceUserDefaultsKey)
        }
    }

    static var ttsInstructions: String {
        get {
            UserDefaults.standard.string(forKey: ttsInstructionsUserDefaultsKey) ?? defaultTTSInstructions
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: ttsInstructionsUserDefaultsKey)
        }
    }

    static func saveAPIKey(_ rawAPIKey: String) throws {
        let apiKey = rawAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            try clearAPIKey()
            return
        }

        let apiKeyData = Data(apiKey.utf8)
        let deleteStatus = SecItemDelete(baseKeychainQuery() as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            throw OpenAISettingsStoreError.keychainDeleteFailed(deleteStatus)
        }

        var addQuery = baseKeychainQuery()
        addQuery[kSecValueData as String] = apiKeyData
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw OpenAISettingsStoreError.keychainSaveFailed(addStatus)
        }
    }

    static func clearAPIKey() throws {
        let status = SecItemDelete(baseKeychainQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw OpenAISettingsStoreError.keychainDeleteFailed(status)
        }
    }

    private static func readAPIKeyFromKeychain() -> String? {
        var query = baseKeychainQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let apiKeyData = result as? Data,
              let apiKey = String(data: apiKeyData, encoding: .utf8) else {
            return nil
        }

        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedAPIKey.isEmpty ? nil : trimmedAPIKey
    }

    private static func baseKeychainQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount
        ]
    }
}
