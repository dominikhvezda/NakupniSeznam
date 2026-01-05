# 🛒 Nákupní Seznam - iOS Aplikace

Minimalistická iOS aplikace pro vytváření nákupních seznamů pomocí **hlasu, textu nebo schránky** s automatickým řazením podle kategorií.

## ✨ Funkce

### 3 Způsoby zadání seznamu:
- 🎤 **Hlasové nahrání** - Nahrávání nákupního seznamu českou řečí pomocí Speech Framework
- ⌨️ **Ruční psaní** - Napsání seznamu do textového pole
- 📋 **Vložení ze schránky** - Automatické načtení textu ze schránky

### AI Zpracování (Volitelné):
- 🤖 **Inteligentní parsing** - Claude AI rozpozná položky z přirozeného jazyka bez potřeby čárek
- ⚙️ **Nastavitelné** - Můžete zapnout/vypnout AI zpracování v nastavení
- 🔑 **API klíč** - Zadejte svůj Anthropic API klíč v nastavení
- ↩️ **Fallback** - Při chybě AI automaticky použije ruční parsing

### Další funkce:
- 🔄 Automatické rozpoznávání české řeči
- 🗂️ Inteligentní kategorizace surovin (pečivo, maso, mléčné výrobky, zelenina, ovoce, kosmetika, ostatní)
- 📊 Automatické seřazení položek podle kategorií
- • Zobrazení surovin v přehledných odrážkách (bez nadpisů kategorií)
- 📅 Ukládání seznamů s názvem podle data vytvoření
- 📜 Historie všech uložených seznamů
- ✅ Možnost označit a smazat vybrané seznamy
- 🗑️ Funkce "Smazat vše"

## 🛠 Technologie

- **SwiftUI** - Moderní UI framework
- **Speech Framework** - Rozpoznávání české řeči
- **SwiftData** - Persistentní ukládání dat
- **AVFoundation** - Práce s audio
- **Anthropic Claude API** - AI-powered text processing (volitelné)

## 📋 Požadavky

- iOS 17.0+
- Xcode 15.0+
- Fyzické zařízení (Speech Recognition nefunguje na simulátoru)
- Mikrofon

## 🚀 Instalace

1. **Naklonujte repozitář:**
   ```bash
   git clone https://github.com/dominikhvezda/NakupniSeznam.git
   cd NakupniSeznam
   ```

2. **Otevřete projekt v Xcode:**
   ```bash
   open NakupniSeznam.xcodeproj
   ```

3. **Nastavte oprávnění:**
   - V Xcode: Projekt → Target "NakupniSeznam" → **Info** tab
   - Přidejte do **"Custom iOS Target Properties"**:
     - `Privacy - Microphone Usage Description`
     - `Privacy - Speech Recognition Usage Description`

4. **Připojte iPhone a spusťte:**
   - Vyberte své iPhone v Xcode
   - Stiskněte `Cmd+R` nebo klikněte "Run"
   - ⚠️ Speech Recognition vyžaduje fyzické zařízení!

## 📱 Jak používat

### Nastavení AI zpracování (volitelné):

1. **Otevřete nastavení**: Klikněte na ikonu ozubeného kola (⚙️) v levém horním rohu
2. **Zapněte AI zpracování**: Přepněte přepínač "Použít AI zpracování"
3. **Zadejte API klíč**:
   - Získejte klíč na [console.anthropic.com](https://console.anthropic.com/)
   - Vložte klíč do pole a klikněte "Uložit"
   - Klíč se automaticky ověří
4. **Hotovo**: S AI můžete psát seznamy v přirozeném jazyce (např. "potřebuji mléko máslo a chleba")

### Vytvoření nového seznamu:

1. **Vyberte režim** v horní části obrazovky:
   - 🎤 **Hlas** - pro hlasové nahrání
   - ⌨️ **Text** - pro ruční psaní
   - 📋 **Schránka** - pro vložení ze schránky

2. **Zadejte seznam:**
   - **Hlasový režim**: Klikněte na modrý mikrofon, nadiktujte seznam, klikněte na červené tlačítko
   - **Textový režim**: Napište seznam (s AI můžete použít přirozený jazyk, bez AI oddělte položky čárkou)
   - **Režim schránky**: Zkopírujte seznam do schránky a přepněte na tento režim

3. **Vytvořte seznam**: Klikněte "Vytvořit seznam" → aplikace zobrazí seřazené položky

4. **Uložte**: Klikněte "Uložit seznam" → seznam se uloží s dnešním datem

5. **Historie**: Ikona hodin (⏱️) v pravém horním rohu otevře historii

## 💡 Příklad použití

**Bez AI (oddělení čárkami):**
```
Chleba, rohlíky, mléko, jogurt, kuřecí maso, mrkev, rajčata, jablka, banány
```

**S AI (přirozený jazyk):**
```
Potřebuji koupit chleba a rohlíky, pak mléko s jogurtem, také kuřecí maso.
Nesmím zapomenout na zeleninu - mrkev a rajčata, a ovoce jako jablka a banány.
```

Aplikace automaticky seřadí:
- Chleba
- Rohlíky
- Kuřecí maso
- Mléko
- Jogurt
- Mrkev
- Rajčata
- Jablka
- Banány

## 📂 Struktura projektu

```
NakupniSeznam/
├── Models/
│   └── ShoppingList.swift          # SwiftData modely
├── Managers/
│   ├── SpeechRecognizer.swift      # Rozpoznávání řeči
│   ├── CategoryManager.swift       # Kategorizace surovin
│   ├── AnthropicAPIManager.swift   # Komunikace s Claude API
│   └── SettingsManager.swift       # Správa nastavení a API klíče
├── Views/
│   ├── ContentView.swift           # Hlavní obrazovka
│   ├── HistoryView.swift           # Historie seznamů
│   └── SettingsView.swift          # Nastavení aplikace
└── NakupniSeznamApp.swift          # Entry point
```

## 🎨 Design

Minimalistický design s důrazem na jednoduchost a rychlost použití:
- Segmented Picker pro výběr módu
- Velké, snadno dostupné tlačítko pro hlasové nahrávání
- TextEditor s placeholderem pro ruční zadání
- Ikona schránky s informacemi o stavu
- Přehledné odrážky pro položky
- Zelené tlačítko pro uložení
- Ikona ozubeného kola pro nastavení
- Loading overlay při zpracování AI
- Maskované zobrazení API klíče pro bezpečnost

## 🐛 Řešení problémů

**Speech Recognition nefunguje:**
- Ujistěte se, že používáte fyzické iPhone (ne simulátor)
- Zkontrolujte oprávnění v Nastavení → NakupniSeznam
- Ověřte, že máte aktivní internetové připojení

**Build Failed:**
- Zkontrolujte, že máte nastaveného Team v Signing & Capabilities
- Proveďte Clean Build Folder (`Shift+Cmd+K`)
- Smažte Derived Data

## 📝 Poznámky

- Aplikace vyžaduje povolení přístupu k mikrofonu a rozpoznávání řeči
- Pro nejlepší výsledky mluvte zřetelně a v klidném prostředí
- Seznam se automaticky uloží s názvem ve formátu "4. 1. 2026"
- Speech Recognition vyžaduje online připojení
- **AI zpracování je volitelné** - aplikace funguje i bez API klíče
- Při chybě AI se automaticky použije fallback na ruční parsing
- Anthropic nabízí free tier s omezeným počtem requestů
- API klíč je uložen bezpečně v UserDefaults

## 👨‍💻 Autor

**Dominik Hvězda**
- GitHub: [@dominikhvezda](https://github.com/dominikhvezda)

## 📄 Licence

Tento projekt je vytvořen pro osobní použití.

---

🤖 Vytvořeno s pomocí [Claude Code](https://claude.com/claude-code)
