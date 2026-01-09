import Foundation
import UIKit

/// Výsledek analýzy ledničky
struct FridgeAnalysisResult {
    let itemsFound: [String]      // Položky nalezené v ledničce
    let suggestions: [String]     // Doporučené položky k nákupu
}

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
        Parse this shopping list into individual items WITH QUANTITIES. Return ONLY a valid JSON array of strings.
        No explanations, no markdown, just the JSON array.

        QUANTITY FORMATTING RULES:
        - "dvakrát X" or "2x X" → "2x X"
        - "třikrát X" → "3x X"
        - "čtyřikrát X" → "4x X"
        - "300 gramů X" or "300g X" → "300g X"
        - "půl kila X" → "500g X"
        - "kilo X" → "1kg X"
        - "litr X" → "1l X"
        - "půl litru X" → "0.5l X"
        - If no quantity specified, just use item name

        Input: \(text)

        Example output: ["2x chleba", "300g kuřete", "1l mléka", "rohlíky"]
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

    /// Analyzuje fotku ledničky a vrátí položky, které jsou v ledničce a co chybí
    /// - Parameters:
    ///   - image: Obrázek ledničky
    ///   - apiKey: API klíč pro Anthropic
    /// - Returns: Tuple obsahující položky v ledničce a doporučené položky
    func analyzeFridgeImage(_ image: UIImage, apiKey: String) async throws -> FridgeAnalysisResult {
        guard !apiKey.isEmpty else {
            throw APIError.missingAPIKey
        }

        // Konverze obrázku na base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.invalidImage
        }
        let base64Image = imageData.base64EncodedString()

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

        // Prompt pro Claude Vision
        let prompt = """
        Analyzuj tuto fotku ledničky a poskytni následující informace:

        1. Jaké potraviny vidíš v ledničce? (seznam položek)
        2. Jaké běžné základní potraviny by mohly chybět pro kompletní zásobu? (max 8 návrhů)

        Vrať POUZE platný JSON objekt v tomto formátu (bez markdown, bez vysvětlení):
        {
            "itemsFound": ["mléko", "jogurt", "šunka"],
            "suggestions": ["chleba", "máslo", "vejce", "sýr"]
        }
        """

        // Body requestu s obrázkem
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 400,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": prompt
                        ]
                    ]
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

        // Parsování výsledku
        let result = try parseFridgeAnalysisResult(textContent)
        return result
    }

    /// Parsuje výsledek analýzy ledničky z textu
    private func parseFridgeAnalysisResult(_ text: String) throws -> FridgeAnalysisResult {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Odstranění markdown code blocků
        var jsonString = cleanedText
        if let startRange = cleanedText.range(of: "```json"),
           let endRange = cleanedText.range(of: "```", range: startRange.upperBound..<cleanedText.endIndex) {
            jsonString = String(cleanedText[startRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let startRange = cleanedText.range(of: "```"),
                  let endRange = cleanedText.range(of: "```", range: startRange.upperBound..<cleanedText.endIndex) {
            jsonString = String(cleanedText[startRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Najdeme první { a poslední }
        if let startIndex = jsonString.firstIndex(of: "{"),
           let endIndex = jsonString.lastIndex(of: "}") {
            jsonString = String(jsonString[startIndex...endIndex])
        }

        // Parsování JSON
        guard let data = jsonString.data(using: .utf8),
              let resultDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let itemsFound = resultDict["itemsFound"] as? [String],
              let suggestions = resultDict["suggestions"] as? [String] else {
            throw APIError.invalidJSONResponse
        }

        return FridgeAnalysisResult(
            itemsFound: itemsFound.filter { !$0.isEmpty },
            suggestions: suggestions.filter { !$0.isEmpty }
        )
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
    case invalidImage
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
        case .invalidImage:
            return "Nepodařilo se zpracovat obrázek."
        case .httpError(let statusCode):
            return "HTTP chyba: \(statusCode)"
        case .rateLimitExceeded:
            return "Překročen limit požadavků. Zkuste to později."
        }
    }
}
