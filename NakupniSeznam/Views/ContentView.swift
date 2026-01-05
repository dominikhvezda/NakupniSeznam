import SwiftUI
import SwiftData
import Speech

// Enum pro režimy zadávání seznamu
enum InputMode: String, CaseIterable {
    case voice = "Hlas"
    case text = "Text"
    case clipboard = "Schránka"
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var settings = SettingsManager.shared

    // Stavy pro UI
    @State private var showingHistory = false
    @State private var showingSettings = false
    @State private var parsedItems: [ShoppingItem] = []
    @State private var showingSaveButton = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false

    // Nové stavy pro různé módy zadávání
    @State private var selectedMode: InputMode = .voice
    @State private var manualText: String = ""
    @State private var clipboardText: String = ""

    // Sdílený DateFormatter pro efektivitu
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d. M. yyyy"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Picker pro výběr módu zadávání
                Picker("Režim zadávání", selection: $selectedMode) {
                    ForEach(InputMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 10)
                .onChange(of: selectedMode) { _, newMode in
                    handleModeChange(newMode)
                }

                // Podmíněné zobrazení podle vybraného módu
                switch selectedMode {
                case .voice:
                    voiceInputView
                case .text:
                    textInputView
                case .clipboard:
                    clipboardInputView
                }

                // Zobrazení přepisu nebo zadaného textu
                if !getCurrentText().isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Zadaný text:")
                            .font(.headline)

                        ScrollView {
                            Text(getCurrentText())
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .frame(maxHeight: 100)
                    }
                    .padding(.horizontal)
                }

                // Seznam rozpoznaných surovin
                if !parsedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nákupní seznam:")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(parsedItems, id: \.id) { item in
                                    HStack {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 6, height: 6)

                                        Text(item.name)
                                            .font(.body)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                Spacer()

                // Tlačítko "Vytvořit seznam" - zobrazí se po zadání textu
                if !getCurrentText().isEmpty && parsedItems.isEmpty {
                    Button(action: processText) {
                        Text("Vytvořit seznam")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }

                // Tlačítko "Uložit seznam" - zobrazí se po vytvoření seznamu
                if showingSaveButton && !parsedItems.isEmpty {
                    Button(action: saveShoppingList) {
                        Text("Uložit seznam")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Nákupní Seznam")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingHistory) {
                HistoryView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .alert("Chyba při zpracování", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .overlay {
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))

                            Text(settings.useAI && settings.hasAPIKey ? "AI zpracovává seznam..." : "Zpracovávám seznam...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(30)
                        .background(Color.gray.opacity(0.9))
                        .cornerRadius(15)
                    }
                }
            }
        }
    }

    // MARK: - View Components pro jednotlivé módy

    /// View pro hlasové zadávání
    private var voiceInputView: some View {
        VStack(spacing: 20) {
            Button(action: {
                if speechRecognizer.isRecording {
                    speechRecognizer.stopRecording()
                } else {
                    speechRecognizer.startRecording()
                    parsedItems = []
                    showingSaveButton = false
                }
            }) {
                ZStack {
                    Circle()
                        .fill(speechRecognizer.isRecording ? Color.red : Color.blue)
                        .frame(width: 100, height: 100)
                        .shadow(radius: 10)

                    Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
            }
            .disabled(speechRecognizer.authorizationStatus != .authorized)

            Text(speechRecognizer.isRecording ? "Nahrávám..." : "Stiskněte pro nahrání")
                .font(.headline)
                .foregroundColor(.secondary)

            if speechRecognizer.authorizationStatus != .authorized {
                Text("Povolte přístup k mikrofonu a rozpoznávání řeči v Nastavení")
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.top, 20)
    }

    /// View pro ruční psaní
    private var textInputView: some View {
        VStack(spacing: 15) {
            Text("Napište seznam:")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            ZStack(alignment: .topLeading) {
                // Pozadí a ohraničení
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .frame(height: 200)

                // TextEditor bez stylingu
                if #available(iOS 16.0, *) {
                    TextEditor(text: $manualText)
                        .padding(8)
                        .frame(height: 200)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                } else {
                    TextEditor(text: $manualText)
                        .padding(8)
                        .frame(height: 200)
                        .background(Color.clear)
                }

                // Placeholder
                if manualText.isEmpty {
                    Text("Napište seznam...\nNapř: Chleba, mléko, máslo")
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.top, 16)
                        .padding(.leading, 13)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 10)
    }

    /// View pro vložení ze schránky
    private var clipboardInputView: some View {
        VStack(spacing: 15) {
            Text("Text ze schránky:")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            if clipboardText.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)

                    Text("Schránka je prázdná")
                        .foregroundColor(.secondary)

                    Text("Zkopírujte seznam do schránky a přepněte na tento režim")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(height: 200)
            } else {
                ZStack(alignment: .topLeading) {
                    // Pozadí a ohraničení
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        .frame(height: 200)

                    // TextEditor bez stylingu
                    if #available(iOS 16.0, *) {
                        TextEditor(text: $clipboardText)
                            .padding(8)
                            .frame(height: 200)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                    } else {
                        TextEditor(text: $clipboardText)
                            .padding(8)
                            .frame(height: 200)
                            .background(Color.clear)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 10)
    }

    // MARK: - Helper Functions

    /// Vrátí aktuální text podle vybraného módu
    private func getCurrentText() -> String {
        switch selectedMode {
        case .voice:
            return speechRecognizer.transcript
        case .text:
            return manualText
        case .clipboard:
            return clipboardText
        }
    }

    /// Zpracuje změnu módu zadávání
    private func handleModeChange(_ newMode: InputMode) {
        // Zastavíme nahrávání, pokud běží
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        }

        // Resetujeme stav
        parsedItems = []
        showingSaveButton = false

        // Pokud přepínáme na režim schránky, načteme obsah schránky
        if newMode == .clipboard {
            loadClipboard()
        }
    }

    /// Načte text ze schránky
    private func loadClipboard() {
        #if os(iOS)
        if let clipboardString = UIPasteboard.general.string {
            clipboardText = clipboardString
        } else {
            clipboardText = ""
        }
        #endif
    }

    /// Zpracuje text a vytvoří seznam položek
    private func processText() {
        let textToProcess = getCurrentText()
        guard !textToProcess.isEmpty else { return }

        isProcessing = true
        errorMessage = nil

        Task {
            do {
                // Pokusíme se použít AI zpracování
                let items = try await CategoryManager.shared.parseAndCategorizeItems(from: textToProcess)

                await MainActor.run {
                    parsedItems = items
                    isProcessing = false

                    if !parsedItems.isEmpty {
                        showingSaveButton = true
                    }
                }
            } catch {
                // Při chybě AI použijeme fallback na ruční parsing
                await MainActor.run {
                    parsedItems = CategoryManager.shared.parseAndCategorizeItemsManually(from: textToProcess)
                    isProcessing = false

                    // Zobrazíme chybovou hlášku pouze pokud šlo o AI chybu
                    if settings.useAI && settings.hasAPIKey {
                        errorMessage = error.localizedDescription
                        showingErrorAlert = true
                    }

                    if !parsedItems.isEmpty {
                        showingSaveButton = true
                    }
                }
            }
        }
    }

    /// Uloží nákupní seznam do databáze
    private func saveShoppingList() {
        guard !parsedItems.isEmpty else { return }

        // Vytvoříme název podle aktuálního data
        let listName = Self.dateFormatter.string(from: Date())

        // Vytvoříme nový seznam
        let newList = ShoppingList(name: listName, items: parsedItems)

        // Uložíme do databáze
        modelContext.insert(newList)

        do {
            try modelContext.save()
        } catch {
            print("Chyba při ukládání seznamu: \(error.localizedDescription)")
            // V případě chyby nepřecházíme do historie
            return
        }

        // Resetujeme UI podle módu
        resetUI()

        // Zobrazíme historii
        showingHistory = true
    }

    /// Resetuje UI do výchozího stavu
    private func resetUI() {
        parsedItems = []
        showingSaveButton = false

        switch selectedMode {
        case .voice:
            speechRecognizer.reset()
        case .text:
            manualText = ""
        case .clipboard:
            clipboardText = ""
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ShoppingList.self, inMemory: true)
}
