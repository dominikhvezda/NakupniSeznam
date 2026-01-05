import Foundation
import Speech
import AVFoundation
import Combine

/// Třída pro rozpoznávání české řeči pomocí Speech Framework
class SpeechRecognizer: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "cs-CZ"))
        // Nebudeme volat requestAuthorization() v init - vyvoláme ho až při prvním použití
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    func requestAuthorization() async {
        let currentStatus = SFSpeechRecognizer.authorizationStatus()

        await MainActor.run {
            self.authorizationStatus = currentStatus
        }

        if currentStatus == .notDetermined {
            let newStatus = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }

            await MainActor.run {
                self.authorizationStatus = newStatus
            }
        }
    }

    func startRecording() {
        // Pokud ještě nemáme oprávnění, vyžádáme ho
        if authorizationStatus == .notDetermined {
            Task {
                await requestAuthorization()
                // Po získání oprávnění znovu zavoláme startRecording
                if authorizationStatus == .authorized {
                    startRecording()
                }
            }
            return
        }

        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("Speech recognizer není dostupný")
            return
        }

        guard authorizationStatus == .authorized else {
            print("Není uděleno oprávnění pro rozpoznávání řeči")
            return
        }

        // Zastavíme předchozí nahrávání, pokud běží
        if isRecording {
            stopRecording()
        }

        do {
            // Nastavení audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            // Vytvoření nového audio enginu
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else { return }

            // Vytvoření recognition requestu
            request = SFSpeechAudioBufferRecognitionRequest()
            guard let request = request else { return }
            request.shouldReportPartialResults = true

            // Nastavení češtiny
            if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "cs-CZ")) {
                task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                    guard let self = self else { return }

                    if let result = result {
                        let transcriptText = result.bestTranscription.formattedString
                        Task { @MainActor in
                            self.transcript = transcriptText
                        }
                    }

                    if error != nil || result?.isFinal == true {
                        Task {
                            self.stopRecording()
                        }
                    }
                }
            }

            // Začneme nahrávat z mikrofonu
            let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
            audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            DispatchQueue.main.async {
                self.transcript = ""
                self.isRecording = true
            }

        } catch {
            print("Chyba při spuštění nahrávání: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()

        audioEngine = nil
        request = nil
        task = nil

        DispatchQueue.main.async {
            self.isRecording = false
        }
    }

    func reset() {
        DispatchQueue.main.async {
            self.transcript = ""
        }
    }
}
