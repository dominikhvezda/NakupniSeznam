import Foundation

/// Manager pro komunikaci s Claude API (Anthropic)
class AnthropicAPIManager {
    static let shared = AnthropicAPIManager()

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"
    private let apiVersion = "2023-06-01"

    private init() {}

    /// Zpracuje text pomocí Claude API a vrátí pole položek
    /// - Parameters:
    ///   - text: Text k zpracování (může obsahovat přirozený jazyk)
    ///   - apiKey: API klíč pro Anthropic
    /// - Returns: Pole názvů položek
    func parseShoppingList(text: String, apiKey: String) async throws -> [String] {
        guard !apiKey.isEmpty else {
            throw APIError.missingAPIKey
        }

        guard !text.isEmpty else {
            throw APIError.emptyInput
        }

        // Vytvoření URL
        guard let url = URL(string: baseURL) else {
            throw APIError.invalidURL
        }

        // Vytvoření requestu
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        // Prompt pro Claude
        let prompt = """
        Parse this shopping list into individual items. Return ONLY a valid JSON array of strings with item names.
        No explanations, no markdown, just the JSON array.

        Input: \(text)

        Example output format: ["mléko", "rohlíky", "kuřecí maso"]
        """

        // Body requestu
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 200,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Odeslání requestu
        let (data, response) = try await URLSession.shared.data(for: request)

        // Kontrola HTTP odpovědi
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.invalidAPIKey
            } else if httpResponse.statusCode == 429 {
                throw APIError.rateLimitExceeded
            } else {
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }
        }

        // Parsování odpovědi
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let textContent = firstContent["text"] as? String else {
            throw APIError.invalidResponse
        }

        // Extrakce JSON array z odpovědi
        let items = try parseItemsFromText(textContent)

        return items
    }

    /// Parsuje pole položek z textu Claude odpovědi
    private func parseItemsFromText(_ text: String) throws -> [String] {
        // Najdeme JSON array v textu
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Pokusíme se najít JSON array (může být obalen v markdown nebo textu)
        var jsonString = cleanedText

        // Odstranění markdown code blocků
        if let startRange = cleanedText.range(of: "```json"),
           let endRange = cleanedText.range(of: "```", range: startRange.upperBound..<cleanedText.endIndex) {
            jsonString = String(cleanedText[startRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let startRange = cleanedText.range(of: "```"),
                  let endRange = cleanedText.range(of: "```", range: startRange.upperBound..<cleanedText.endIndex) {
            jsonString = String(cleanedText[startRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Najdeme první [ a poslední ]
        if let startIndex = jsonString.firstIndex(of: "["),
           let endIndex = jsonString.lastIndex(of: "]") {
            jsonString = String(jsonString[startIndex...endIndex])
        }

        // Parsování JSON
        guard let data = jsonString.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [String] else {
            throw APIError.invalidJSONResponse
        }

        // Filtrování prázdných položek
        return array.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Validuje API klíč
    func validateAPIKey(_ apiKey: String) async -> Bool {
        do {
            _ = try await parseShoppingList(text: "test", apiKey: apiKey)
            return true
        } catch APIError.invalidAPIKey {
            return false
        } catch {
            // Jiné chyby (např. síťové) nepovažujeme za neplatný klíč
            return true
        }
    }
}

/// Chyby API
enum APIError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case emptyInput
    case invalidURL
    case invalidResponse
    case invalidJSONResponse
    case httpError(statusCode: Int)
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API klíč nebyl nastaven. Přejděte do Nastavení."
        case .invalidAPIKey:
            return "Neplatný API klíč. Zkontrolujte svůj klíč v Nastavení."
        case .emptyInput:
            return "Text nemůže být prázdný."
        case .invalidURL:
            return "Chyba při vytváření URL."
        case .invalidResponse:
            return "Neplatná odpověď ze serveru."
        case .invalidJSONResponse:
            return "Chyba při zpracování odpovědi."
        case .httpError(let statusCode):
            return "HTTP chyba: \(statusCode)"
        case .rateLimitExceeded:
            return "Překročen limit požadavků. Zkuste to později."
        }
    }
}
