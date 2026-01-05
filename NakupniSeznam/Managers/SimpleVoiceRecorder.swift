import Foundation
import Speech
import AVFoundation
import Combine

/// Simple, working voice recorder with proper permission handling
class SimpleVoiceRecorder: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var errorMessage: String?

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "cs-CZ"))

    init() {
        print("🎙️ SimpleVoiceRecorder initialized")
    }

    deinit {
        print("🎙️ SimpleVoiceRecorder deallocating")
        stopRecording()
    }

    /// Check and request permissions if needed
    func requestPermissionsAndStartRecording() {
        print("🎙️ requestPermissionsAndStartRecording called")

        // Check speech recognition authorization
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        print("🎙️ Speech status: \(speechStatus.rawValue)")

        switch speechStatus {
        case .notDetermined:
            print("🎙️ Requesting speech recognition permission...")
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                print("🎙️ Speech permission result: \(status.rawValue)")
                DispatchQueue.main.async {
                    if status == .authorized {
                        self?.checkMicrophonePermission()
                    } else {
                        self?.errorMessage = "Speech recognition not authorized"
                    }
                }
            }
        case .authorized:
            print("🎙️ Speech already authorized, checking microphone...")
            checkMicrophonePermission()
        case .denied, .restricted:
            print("🎙️ Speech recognition denied or restricted")
            errorMessage = "Please enable speech recognition in Settings"
        @unknown default:
            print("🎙️ Unknown speech recognition status")
            errorMessage = "Unknown permission status"
        }
    }

    private func checkMicrophonePermission() {
        print("🎙️ Checking microphone permission...")

        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            print("🎙️ Microphone permission: \(granted)")
            DispatchQueue.main.async {
                if granted {
                    self?.startRecording()
                } else {
                    self?.errorMessage = "Please enable microphone in Settings"
                }
            }
        }
    }

    func startRecording() {
        print("🎙️ === START RECORDING ===")

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("🎙️ ERROR: Speech recognizer not available")
            errorMessage = "Speech recognizer not available"
            return
        }

        // Stop any existing recording
        if isRecording {
            print("🎙️ Already recording, stopping first...")
            stopRecording()
        }

        do {
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("🎙️ Audio session configured")

            // Create audio engine
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else {
                print("🎙️ ERROR: Failed to create audio engine")
                return
            }

            // Create recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                print("🎙️ ERROR: Failed to create recognition request")
                return
            }
            recognitionRequest.shouldReportPartialResults = true

            // Create recognition task
            print("🎙️ Creating recognition task...")
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }

                if let result = result {
                    let text = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        self.transcript = text
                        print("🎙️ Transcript: \(text)")
                    }
                }

                if let error = error {
                    print("🎙️ Recognition error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                        self.stopRecording()
                    }
                }

                if result?.isFinal == true {
                    print("🎙️ Recognition final, stopping...")
                    DispatchQueue.main.async {
                        self.stopRecording()
                    }
                }
            }

            // Install tap on audio input
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            print("🎙️ Installing tap on audio input...")

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak recognitionRequest] buffer, _ in
                recognitionRequest?.append(buffer)
            }

            // Start audio engine
            print("🎙️ Starting audio engine...")
            audioEngine.prepare()
            try audioEngine.start()

            // Update state
            transcript = ""
            isRecording = true
            errorMessage = nil
            print("🎙️ === RECORDING STARTED SUCCESSFULLY ===")

        } catch {
            print("🎙️ ERROR: Failed to start recording: \(error.localizedDescription)")
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            stopRecording()
        }
    }

    func stopRecording() {
        print("🎙️ === STOP RECORDING ===")

        // Stop audio engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        // End recognition
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        // Clean up
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil

        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("🎙️ Audio session deactivated")
        } catch {
            print("🎙️ Warning: Failed to deactivate audio session: \(error.localizedDescription)")
        }

        // Update state
        isRecording = false
        print("🎙️ === RECORDING STOPPED ===")
    }

    func reset() {
        transcript = ""
        errorMessage = nil
        print("🎙️ Reset complete")
    }
}
