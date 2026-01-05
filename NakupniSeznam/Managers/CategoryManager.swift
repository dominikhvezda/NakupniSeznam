import Foundation

class CategoryManager {
    static let shared = CategoryManager()

    private init() {}

    // Slovník klíčových slov pro jednotlivé kategorie
    private let categoryKeywords: [ItemCategory: [String]] = [
        .bakery: ["chléb", "chleba", "rohlík", "rohlíky", "bageta", "bagetu", "houska", "housky", "croissant", "koláč", "koláče", "buchta", "buchty", "pečivo", "toast", "žemle", "žemly", "houska", "housky"],
        .meat: ["maso", "kuře", "kuřecí", "vepřové", "hovězí", "salám", "klobása", "klobásy", "šunka", "šunku", "párek", "párky", "krůta", "krůtí", "vepřový", "telecí", "uzené", "šunka"],
        .dairy: ["mléko", "jogurt", "sýr", "máslo", "tvaroh", "smetana", "smetanu", "kefír", "podmáslí", "niva", "eidam", "ementál", "parmazán", "mozzarella", "níva", "niva", "sýr", "smetana"],
        .vegetables: ["mrkev", "rajče", "rajčata", "okurka", "okurku", "okurky", "paprika", "papriku", "papriky", "cibule", "cibuli", "česnek", "brambory", "brambor", "zelí", "salát", "salátu", "petržel", "pórek", "cuketa", "cuketu", "lilek", "rajčata"],
        .fruits: ["jablko", "jablka", "banán", "banány", "pomeranč", "pomeranče", "mandarinka", "mandarinky", "hrozny", "hroznů", "jahody", "jahod", "borůvky", "maliny", "hruška", "hrušky", "citrón", "citróny", "ananas", "kiwi", "melon"],
        .cosmetics: ["šampon", "mýdlo", "pasta", "kartáček", "kartáčky", "krém", "kosmetika", "deodorant", "gel", "toaletní papír", "papír", "ubrousky", "ubrousek", "kondicionér", "zubní"]
    ]

    func categorizeItem(_ itemName: String) -> ItemCategory {
        let lowercasedItem = itemName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Projdeme všechny kategorie a hledáme shodu
        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                if lowercasedItem.contains(keyword) {
                    return category
                }
            }
        }

        return .other
    }

    /// Parsuje a kategorizuje položky pomocí AI nebo fallbacku na ruční parsing
    /// - Parameter text: Text k zpracování
    /// - Returns: Pole ShoppingItem
    func parseAndCategorizeItems(from text: String) async throws -> [ShoppingItem] {
        let settings = SettingsManager.shared

        // Pokusíme se použít AI, pokud je zapnuto a máme API klíč
        if settings.useAI && settings.hasAPIKey {
            do {
                let itemNames = try await AnthropicAPIManager.shared.parseShoppingList(
                    text: text,
                    apiKey: settings.apiKey
                )
                return categorizeItems(itemNames)
            } catch {
                // Při chybě AI použijeme fallback
                print("AI parsing failed: \(error.localizedDescription), using fallback")
                throw error
            }
        }

        // Fallback: původní metoda
        return parseAndCategorizeItemsManually(from: text)
    }

    /// Původní metoda ručního parsování (fallback)
    func parseAndCategorizeItemsManually(from text: String) -> [ShoppingItem] {
        // Rozdělíme text na jednotlivé položky (čárka, středník, nový řádek)
        // Tečku nepoužíváme jako separator kvůli číslům (např. "1.5 kg")
        let separators = CharacterSet(charactersIn: ",;\n")
        let rawItems = text.components(separatedBy: separators)

        var items: [ShoppingItem] = []
        var categoryCount: [ItemCategory: Int] = [:]

        for rawItem in rawItems {
            let trimmedItem = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)

            // Přeskočíme prázdné položky
            if trimmedItem.isEmpty { continue }

            // Kategorizujeme položku
            let category = categorizeItem(trimmedItem)

            // Spočítáme, kolik položek již máme v dané kategorii (pro sortOrder)
            let count = categoryCount[category, default: 0]
            categoryCount[category] = count + 1

            // Vypočítáme sortOrder: kategorie * 1000 + pozice v kategorii
            let sortOrder = category.order * 1000 + count

            let item = ShoppingItem(name: trimmedItem, category: category, sortOrder: sortOrder)
            items.append(item)
        }

        // Seřadíme položky podle sortOrder
        return items.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Kategorizuje pole názvů položek
    private func categorizeItems(_ itemNames: [String]) -> [ShoppingItem] {
        var items: [ShoppingItem] = []
        var categoryCount: [ItemCategory: Int] = [:]

        for itemName in itemNames {
            let trimmedItem = itemName.trimmingCharacters(in: .whitespacesAndNewlines)

            // Přeskočíme prázdné položky
            if trimmedItem.isEmpty { continue }

            // Kategorizujeme položku
            let category = categorizeItem(trimmedItem)

            // Spočítáme, kolik položek již máme v dané kategorii (pro sortOrder)
            let count = categoryCount[category, default: 0]
            categoryCount[category] = count + 1

            // Vypočítáme sortOrder: kategorie * 1000 + pozice v kategorii
            let sortOrder = category.order * 1000 + count

            let item = ShoppingItem(name: trimmedItem, category: category, sortOrder: sortOrder)
            items.append(item)
        }

        // Seřadíme položky podle sortOrder
        return items.sorted { $0.sortOrder < $1.sortOrder }
    }
}
