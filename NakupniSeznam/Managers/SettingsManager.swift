import Foundation
import Combine

/// Manager pro ukládání nastavení aplikace
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "anthropic_api_key")
        }
    }

    @Published var useAI: Bool {
        didSet {
            UserDefaults.standard.set(useAI, forKey: "use_ai_parsing")
        }
    }

    private init() {
        // Načtení uložených hodnot
        self.apiKey = UserDefaults.standard.string(forKey: "anthropic_api_key") ?? ""
        self.useAI = UserDefaults.standard.bool(forKey: "use_ai_parsing")
    }

    /// Smaže API klíč
    func clearAPIKey() {
        apiKey = ""
        UserDefaults.standard.removeObject(forKey: "anthropic_api_key")
    }

    /// Zkontroluje, jestli je API klíč nastaven
    var hasAPIKey: Bool {
        return !apiKey.isEmpty
    }
}
