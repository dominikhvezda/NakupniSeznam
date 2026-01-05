import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = SettingsManager.shared

    @State private var tempAPIKey: String = ""
    @State private var isValidating = false
    @State private var validationMessage: String?
    @State private var showAPIKeyInfo = false

    var body: some View {
        NavigationStack {
            Form {
                // AI Parsing Section
                Section {
                    Toggle("Použít AI zpracování", isOn: $settings.useAI)

                    if settings.useAI {
                        Text("AI inteligentně rozpozná položky z přirozeného jazyka bez potřeby čárek.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("AI Zpracování")
                }

                // API Key Section
                if settings.useAI {
                    Section {
                        HStack {
                            Text("API Klíč")
                                .font(.headline)

                            Spacer()

                            Button(action: { showAPIKeyInfo = true }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                            }
                        }

                        if settings.hasAPIKey {
                            // Zobrazení maskovaného klíče
                            HStack {
                                Text(maskAPIKey(settings.apiKey))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)

                                Spacer()

                                Button("Změnit") {
                                    tempAPIKey = settings.apiKey
                                }
                                .buttonStyle(.bordered)
                            }

                            Button(role: .destructive, action: {
                                settings.clearAPIKey()
                                tempAPIKey = ""
                                validationMessage = nil
                            }) {
                                Text("Smazat API klíč")
                            }
                        } else {
                            // Zadání nového klíče
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("sk-ant-api03-...", text: $tempAPIKey)
                                    .textFieldStyle(.roundedBorder)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .font(.system(.body, design: .monospaced))

                                HStack {
                                    Button(action: validateAndSaveAPIKey) {
                                        if isValidating {
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                                .scaleEffect(0.8)
                                        } else {
                                            Text("Uložit")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(tempAPIKey.isEmpty || isValidating)

                                    if let message = validationMessage {
                                        Text(message)
                                            .font(.caption)
                                            .foregroundColor(message.contains("úspěšně") ? .green : .red)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Anthropic API")
                    } footer: {
                        if !settings.hasAPIKey {
                            Text("API klíč získáte na console.anthropic.com")
                                .font(.caption)
                        }
                    }
                }

                // About Section
                Section {
                    HStack {
                        Text("Verze")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/dominikhvezda/NakupniSeznam")!) {
                        HStack {
                            Text("GitHub")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("O Aplikaci")
                }
            }
            .navigationTitle("Nastavení")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Hotovo") {
                        dismiss()
                    }
                }
            }
            .alert("Jak získat API klíč", isPresented: $showAPIKeyInfo) {
                Button("OK", role: .cancel) { }
                Button("Otevřít console.anthropic.com") {
                    if let url = URL(string: "https://console.anthropic.com/") {
                        #if os(iOS)
                        UIApplication.shared.open(url)
                        #endif
                    }
                }
            } message: {
                Text("""
                1. Jděte na console.anthropic.com
                2. Přihlaste se nebo vytvořte účet
                3. Přejděte do API Keys
                4. Vytvořte nový klíč
                5. Zkopírujte a vložte ho sem

                Poznámka: Anthropic nabízí free tier s omezeným počtem requestů.
                """)
            }
            .onAppear {
                tempAPIKey = settings.apiKey
            }
        }
    }

    /// Maskuje API klíč pro zobrazení
    private func maskAPIKey(_ key: String) -> String {
        guard key.count > 8 else { return String(repeating: "•", count: key.count) }
        let prefix = String(key.prefix(8))
        let masked = String(repeating: "•", count: max(0, key.count - 12))
        let suffix = String(key.suffix(4))
        return "\(prefix)\(masked)\(suffix)"
    }

    /// Validuje a ukládá API klíč
    private func validateAndSaveAPIKey() {
        guard !tempAPIKey.isEmpty else { return }

        isValidating = true
        validationMessage = nil

        Task {
            let isValid = await AnthropicAPIManager.shared.validateAPIKey(tempAPIKey)

            await MainActor.run {
                isValidating = false

                if isValid {
                    settings.apiKey = tempAPIKey
                    validationMessage = "✓ Uloženo úspěšně"

                    // Vyčištění zprávy po 2 sekundách
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        validationMessage = nil
                    }
                } else {
                    validationMessage = "✗ Neplatný klíč"
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
