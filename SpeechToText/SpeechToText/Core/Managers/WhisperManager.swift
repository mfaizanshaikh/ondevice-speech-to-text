import Foundation
import AVFoundation
import WhisperKit

@MainActor
class WhisperManager: ObservableObject {
    static let shared = WhisperManager()

    @Published var isRecording = false
    @Published var currentTranscription = ""
    @Published var modelState: ModelState = .notLoaded

    private var whisperKit: WhisperKit?
    private var audioEngine: AVAudioEngine?
    private var audioBuffers: [Float] = []
    private var audioBufferLock = NSLock()
    private var recordingTask: Task<Void, Never>?

    private let sampleRate: Double = 16000
    private let bufferSize: AVAudioFrameCount = 1024

    private let maxRetries = 5
    private let retryDelays: [UInt64] = [5, 15, 30, 60, 120] // seconds

    private init() {}

    func loadModel(_ model: String = Constants.WhisperModel.defaultModel) async {
        guard !modelState.isLoading else { return }

        await loadModelWithRetry(model, attempt: 0)
    }

    private func loadModelWithRetry(_ model: String, attempt: Int) async {
        modelState = .downloading(progress: 0.0)
        AppState.shared.modelState = .downloading(progress: 0.0)
        print("Loading WhisperKit model: \(model) (attempt \(attempt + 1)/\(maxRetries + 1))")

        do {
            // Use Application Support for persistent model storage
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let downloadFolder = appSupport.appendingPathComponent("SpeechToText/Models")

            // Create directory if it doesn't exist
            try? FileManager.default.createDirectory(at: downloadFolder, withIntermediateDirectories: true)

            print("Download folder: \(downloadFolder.path)")

            let config = WhisperKitConfig(
                model: model,
                downloadBase: downloadFolder,
                verbose: true,
                logLevel: .debug,
                prewarm: true,
                load: true,
                download: true
            )

            whisperKit = try await WhisperKit(config)
            modelState = .ready
            AppState.shared.modelState = .ready
            print("WhisperKit model loaded successfully")
        } catch {
            print("WhisperKit model loading failed: \(error)")

            // Check if this is a network-related error and we should retry
            let errorString = error.localizedDescription.lowercased()
            let isNetworkError = errorString.contains("offline") ||
                                 errorString.contains("network") ||
                                 errorString.contains("internet") ||
                                 errorString.contains("connection") ||
                                 errorString.contains("timed out") ||
                                 errorString.contains("could not connect")

            if isNetworkError && attempt < maxRetries {
                let delaySeconds = retryDelays[min(attempt, retryDelays.count - 1)]
                print("Network error detected. Retrying in \(delaySeconds) seconds...")

                modelState = .error("Network unavailable. Retrying in \(delaySeconds)s...")
                AppState.shared.modelState = .error("Network unavailable. Retrying in \(delaySeconds)s...")

                try? await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)

                // Retry
                await loadModelWithRetry(model, attempt: attempt + 1)
            } else {
                modelState = .error(error.localizedDescription)
                AppState.shared.modelState = .error(error.localizedDescription)
            }
        }
    }

    func startRecording() async {
        guard modelState.isReady, !isRecording else {
            print("Cannot start recording: modelState.isReady=\(modelState.isReady), isRecording=\(isRecording)")
            return
        }

        // Verify microphone permission before accessing audio hardware
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard audioStatus == .authorized else {
            print("Microphone permission not authorized: \(audioStatus.rawValue)")
            return
        }

        audioBufferLock.lock()
        audioBuffers.removeAll()
        audioBufferLock.unlock()
        currentTranscription = ""

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            print("Failed to create AVAudioEngine")
            return
        }

        let inputNode = audioEngine.inputNode

        // Prepare the engine first to ensure hardware is ready
        audioEngine.prepare()

        // Small delay to allow the audio session to fully configure
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let hardwareFormat = inputNode.inputFormat(forBus: 0)

        // Validate hardware format
        guard hardwareFormat.sampleRate > 0 && hardwareFormat.channelCount > 0 else {
            print("Invalid hardware format: sampleRate=\(hardwareFormat.sampleRate), channels=\(hardwareFormat.channelCount)")
            self.audioEngine = nil
            return
        }

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            print("Failed to create target format")
            self.audioEngine = nil
            return
        }

        guard let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat) else {
            print("Failed to create audio converter from \(hardwareFormat) to \(targetFormat)")
            self.audioEngine = nil
            return
        }

        var tapCallCount = 0
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: hardwareFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            tapCallCount += 1
            if tapCallCount == 1 {
                print("Audio tap receiving data, buffer frameLength: \(buffer.frameLength)")
            }

            let ratio = targetFormat.sampleRate / hardwareFormat.sampleRate
            let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
            guard frameCount > 0,
                  let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else {
                if tapCallCount == 1 {
                    print("Failed to create converted buffer")
                }
                return
            }

            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

            if let error = error {
                if tapCallCount == 1 {
                    print("Audio conversion error: \(error)")
                }
                return
            }

            if let channelData = convertedBuffer.floatChannelData?[0] {
                let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(convertedBuffer.frameLength)))
                self.audioBufferLock.lock()
                self.audioBuffers.append(contentsOf: samples)
                self.audioBufferLock.unlock()
            }
        }

        do {
            try audioEngine.start()

            // Verify the engine is actually running
            guard audioEngine.isRunning else {
                print("Audio engine started but is not running")
                inputNode.removeTap(onBus: 0)
                self.audioEngine = nil
                return
            }

            isRecording = true
            print("Recording started successfully, engine running: \(audioEngine.isRunning)")
            print("Input node format: \(inputNode.inputFormat(forBus: 0))")
        } catch {
            print("Failed to start audio engine: \(error)")
            inputNode.removeTap(onBus: 0)
            self.audioEngine = nil
        }
    }

    func stopRecording() async -> TranscriptionResult {
        guard isRecording else {
            print("stopRecording called but not recording")
            return TranscriptionResult(text: "", isFinal: true)
        }

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false

        // Small delay to ensure all buffered audio samples are processed
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Thread-safe copy of audio buffers
        audioBufferLock.lock()
        let buffersCopy = audioBuffers
        audioBuffers.removeAll()
        audioBufferLock.unlock()

        print("Audio buffers collected: \(buffersCopy.count) samples (\(String(format: "%.2f", Double(buffersCopy.count) / sampleRate)) seconds)")

        guard !buffersCopy.isEmpty else {
            print("No audio data captured - audio engine may have failed to connect to microphone")
            return TranscriptionResult(text: "", isFinal: true)
        }

        let result = await transcribeAudio(buffersCopy)
        print("Transcription result: '\(result.text)'")
        currentTranscription = result.text

        return result
    }

    private func transcribeAudio(_ samples: [Float]) async -> TranscriptionResult {
        guard let whisperKit = whisperKit else {
            print("Transcription error: WhisperKit not initialized")
            return TranscriptionResult(text: "", isFinal: true)
        }

        // Validate audio has sufficient content
        let duration = Double(samples.count) / sampleRate
        print("Transcribing \(samples.count) samples (\(String(format: "%.2f", duration)) seconds)")

        if duration < 0.5 {
            print("Audio too short for transcription (< 0.5 seconds)")
            return TranscriptionResult(text: "", isFinal: true)
        }

        do {
            let language = AppState.shared.selectedLanguage
            let languageToUse = language == "auto" ? nil : language
            print("Using language: \(languageToUse ?? "auto-detect")")

            let options = DecodingOptions(
                verbose: true,
                task: .transcribe,
                language: languageToUse,
                temperatureFallbackCount: 3,
                sampleLength: 224,
                usePrefillPrompt: true,
                usePrefillCache: true,
                skipSpecialTokens: true,
                withoutTimestamps: true
            )

            let results = try await whisperKit.transcribe(
                audioArray: samples,
                decodeOptions: options
            )

            print("Transcription returned \(results.count) segments")
            for (index, segment) in results.enumerated() {
                print("Segment \(index): '\(segment.text)'")
            }

            let fullText = results.map { $0.text }.joined(separator: " ")
            let trimmedText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)

            return TranscriptionResult(
                text: trimmedText,
                language: languageToUse,
                isFinal: true
            )
        } catch {
            print("Transcription error: \(error)")
            return TranscriptionResult(text: "", isFinal: true)
        }
    }

    func cancelRecording() {
        recordingTask?.cancel()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false
        audioBufferLock.lock()
        audioBuffers.removeAll()
        audioBufferLock.unlock()
        currentTranscription = ""
    }
}
