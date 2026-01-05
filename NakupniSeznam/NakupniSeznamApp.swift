import SwiftUI
import SwiftData

@main
struct NakupniSeznamApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [ShoppingList.self, ShoppingItem.self])
    }
}
