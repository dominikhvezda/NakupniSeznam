import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ShoppingList.createdAt, order: .reverse) private var shoppingLists: [ShoppingList]

    @State private var selectedLists: Set<UUID> = []
    @State private var isEditMode = false
    @State private var showingDeleteAlert = false
    @State private var showingDeleteAllAlert = false

    var body: some View {
        NavigationStack {
            VStack {
                if shoppingLists.isEmpty {
                    ContentUnavailableView(
                        "Žádné seznamy",
                        systemImage: "cart",
                        description: Text("Vytvořte svůj první nákupní seznam")
                    )
                } else {
                    List {
                        ForEach(shoppingLists) { list in
                            NavigationLink {
                                ShoppingListDetailView(shoppingList: list)
                            } label: {
                                HStack {
                                    if isEditMode {
                                        Image(systemName: selectedLists.contains(list.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedLists.contains(list.id) ? .blue : .gray)
                                            .onTapGesture {
                                                toggleSelection(for: list.id)
                                            }
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(list.name)
                                            .font(.headline)

                                        Text("\(list.items.count) položek")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .disabled(isEditMode)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Historie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Zavřít") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !shoppingLists.isEmpty {
                            if isEditMode {
                                Button("Hotovo") {
                                    isEditMode = false
                                    selectedLists.removeAll()
                                }
                            } else {
                                Menu {
                                    Button(action: { isEditMode = true }) {
                                        Label("Vybrat", systemImage: "checkmark.circle")
                                    }

                                    Button(role: .destructive, action: { showingDeleteAllAlert = true }) {
                                        Label("Smazat vše", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if isEditMode && !selectedLists.isEmpty {
                    Button(action: { showingDeleteAlert = true }) {
                        Text("Smazat vybrané (\(selectedLists.count))")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .alert("Smazat vybrané seznamy?", isPresented: $showingDeleteAlert) {
                Button("Zrušit", role: .cancel) { }
                Button("Smazat", role: .destructive) {
                    deleteSelectedLists()
                }
            } message: {
                Text("Tuto akci nelze vrátit zpět.")
            }
            .alert("Smazat všechny seznamy?", isPresented: $showingDeleteAllAlert) {
                Button("Zrušit", role: .cancel) { }
                Button("Smazat vše", role: .destructive) {
                    deleteAllLists()
                }
            } message: {
                Text("Tuto akci nelze vrátit zpět.")
            }
        }
    }

    private func toggleSelection(for id: UUID) {
        if selectedLists.contains(id) {
            selectedLists.remove(id)
        } else {
            selectedLists.insert(id)
        }
    }

    private func deleteSelectedLists() {
        for list in shoppingLists where selectedLists.contains(list.id) {
            modelContext.delete(list)
        }

        do {
            try modelContext.save()
        } catch {
            print("Chyba při mazání vybraných seznamů: \(error.localizedDescription)")
        }

        selectedLists.removeAll()
        isEditMode = false
    }

    private func deleteAllLists() {
        for list in shoppingLists {
            modelContext.delete(list)
        }

        do {
            try modelContext.save()
        } catch {
            print("Chyba při mazání všech seznamů: \(error.localizedDescription)")
        }

        // Resetujeme edit režim po smazání všeho
        selectedLists.removeAll()
        isEditMode = false
    }
}

struct ShoppingListDetailView: View {
    let shoppingList: ShoppingList

    var body: some View {
        List {
            ForEach(shoppingList.items.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { item in
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)

                    Text(item.name)
                        .font(.body)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(shoppingList.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: ShoppingList.self, inMemory: true)
}
