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
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        print("🎤 SpeechRecognizer initialized, status: \(authorizationStatus.rawValue)")
    }

    deinit {
        print("🎤 SpeechRecognizer deallocating")
        cleanupSync()
    }

    func requestAuthorization() async {
        print("🎤 Requesting authorization...")
        let currentStatus = SFSpeechRecognizer.authorizationStatus()

        await MainActor.run {
            self.authorizationStatus = currentStatus
        }

        if currentStatus == .notDetermined {
            let newStatus = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    print("🎤 Authorization result: \(status.rawValue)")
                    continuation.resume(returning: status)
                }
            }

            await MainActor.run {
                self.authorizationStatus = newStatus
            }
        }
    }

    func startRecording() {
        print("🎤 startRecording called, current status: \(authorizationStatus.rawValue)")

        // Pokud ještě nemáme oprávnění, vyžádáme ho
        if authorizationStatus == .notDetermined {
            print("🎤 Authorization not determined, requesting...")
            Task {
                await requestAuthorization()
                // Po získání oprávnění znovu zavoláme startRecording
                if authorizationStatus == .authorized {
                    print("🎤 Authorization granted, starting recording...")
                    startRecording()
                } else {
                    print("🎤 Authorization denied: \(authorizationStatus.rawValue)")
                }
            }
            return
        }

        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("🎤 ERROR: Speech recognizer not available")
            return
        }

        guard authorizationStatus == .authorized else {
            print("🎤 ERROR: Not authorized for speech recognition: \(authorizationStatus.rawValue)")
            return
        }

        // Zastavíme předchozí nahrávání, pokud běží
        if isRecording {
            print("🎤 Already recording, stopping first...")
            stopRecording()
        }

        do {
            print("🎤 Setting up audio session...")
            // Nastavení audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            print("🎤 Creating audio engine...")
            // Vytvoření nového audio enginu
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else {
                print("🎤 ERROR: Failed to create audio engine")
                return
            }

            print("🎤 Creating recognition request...")
            // Vytvoření recognition requestu
            request = SFSpeechAudioBufferRecognitionRequest()
            guard let request = request else {
                print("🎤 ERROR: Failed to create recognition request")
                return
            }
            request.shouldReportPartialResults = true

            print("🎤 Starting recognition task...")
            // FIXED: Use existing recognizer instead of creating new one (memory leak!)
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }

                if let result = result {
                    let transcriptText = result.bestTranscription.formattedString
                    Task { @MainActor in
                        self.transcript = transcriptText
                        print("🎤 Transcript: \(transcriptText)")
                    }
                }

                if let error = error {
                    print("🎤 Recognition error: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.stopRecording()
                    }
                }

                if result?.isFinal == true {
                    print("🎤 Recognition final")
                    Task { @MainActor in
                        self.stopRecording()
                    }
                }
            }

            print("🎤 Installing audio tap...")
            // Začneme nahrávat z mikrofonu
            let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
            audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
                request?.append(buffer)
            }

            print("🎤 Starting audio engine...")
            audioEngine.prepare()
            try audioEngine.start()

            DispatchQueue.main.async {
                self.transcript = ""
                self.isRecording = true
                print("🎤 Recording started successfully!")
            }

        } catch {
            print("🎤 ERROR: Failed to start recording: \(error.localizedDescription)")
            cleanupSync()
        }
    }

    func stopRecording() {
        print("🎤 stopRecording called")
        cleanupSync()
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }

    private func cleanupSync() {
        print("🎤 Cleaning up resources...")

        // Stop and cleanup audio engine
        if let audioEngine = audioEngine {
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        // End audio request
        request?.endAudio()

        // Cancel recognition task
        task?.cancel()

        // Release resources
        audioEngine = nil
        request = nil
        task = nil

        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("🎤 Audio session deactivated")
        } catch {
            print("🎤 Warning: Failed to deactivate audio session: \(error.localizedDescription)")
        }

        print("🎤 Cleanup complete")
    }

    func reset() {
        DispatchQueue.main.async {
            self.transcript = ""
        }
        print("🎤 Transcript reset")
    }
}
