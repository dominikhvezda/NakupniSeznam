import Foundation
import SwiftData

@Model
final class ShoppingList {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ShoppingItem.shoppingList)
    var items: [ShoppingItem]

    init(name: String, createdAt: Date = Date(), items: [ShoppingItem] = []) {
        self.id = UUID()
        self.name = name
        self.createdAt = createdAt
        self.items = items
    }
}

@Model
final class ShoppingItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: ItemCategory
    var sortOrder: Int

    var shoppingList: ShoppingList?

    init(name: String, category: ItemCategory, sortOrder: Int) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.sortOrder = sortOrder
    }
}

enum ItemCategory: String, Codable, CaseIterable {
    case bakery = "Pečivo"
    case meat = "Maso"
    case dairy = "Mléčné výrobky"
    case vegetables = "Zelenina"
    case fruits = "Ovoce"
    case cosmetics = "Kosmetika"
    case other = "Ostatní"

    var order: Int {
        switch self {
        case .bakery: return 0
        case .meat: return 1
        case .dairy: return 2
        case .vegetables: return 3
        case .fruits: return 4
        case .cosmetics: return 5
        case .other: return 6
        }
    }
}
