import Foundation
import AVFoundation
import WhisperKit
import Network
import os.log

private let logger = Logger(subsystem: "com.mfaizanshaikh.speechtotext", category: "WhisperManager")

@MainActor
class WhisperManager: ObservableObject {
    static let shared = WhisperManager()

    @Published var isRecording = false
    @Published var currentTranscription = ""
    @Published var modelState: ModelState = .notLoaded
    @Published var audioLevel: Float = 0
    @Published var isNetworkAvailable = true

    private var whisperKit: WhisperKit?
    private var audioEngine: AVAudioEngine?
    private var audioBuffers: [Float] = []
    private var audioBufferLock = NSLock()
    private var recordingTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?

    private let sampleRate: Double = 16000
    private let bufferSize: AVAudioFrameCount = 1024

    private let maxRetries = 5
    private let retryDelays: [UInt64] = [5, 15, 30, 60, 120] // seconds

    private let networkMonitor = NWPathMonitor()
    private let networkMonitorQueue = DispatchQueue(label: "com.mfaizanshaikh.speechtotext.networkmonitor")

    private init() {
        startNetworkMonitoring()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let available = path.status == .satisfied
                self?.isNetworkAvailable = available
                logger.info("Network status changed: \(available ? "available" : "unavailable")")
            }
        }
        networkMonitor.start(queue: networkMonitorQueue)
    }

    // MARK: - Model Cache Detection

    /// Check if model files already exist on disk (previously downloaded)
    func modelExistsOnDisk(_ model: String) -> Bool {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelFolder = appSupport.appendingPathComponent("Offline Speech to Text/Models")
        let fm = FileManager.default

        guard fm.fileExists(atPath: modelFolder.path) else { return false }

        guard let contents = try? fm.contentsOfDirectory(atPath: modelFolder.path) else { return false }

        for item in contents {
            // WhisperKit stores models in directories like "openai_whisper-large-v3"
            if item.lowercased().contains(model.lowercased()) {
                let itemPath = modelFolder.appendingPathComponent(item)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: itemPath.path, isDirectory: &isDir), isDir.boolValue {
                    if let subContents = try? fm.contentsOfDirectory(atPath: itemPath.path), !subContents.isEmpty {
                        logger.info("Found cached model on disk: \(item) with \(subContents.count) files")
                        return true
                    }
                }
            }
        }
        return false
    }

    /// Delete cached model files to force a fresh download
    func deleteModelCache(_ model: String) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelFolder = appSupport.appendingPathComponent("Offline Speech to Text/Models")
        let fm = FileManager.default

        guard let contents = try? fm.contentsOfDirectory(atPath: modelFolder.path) else { return }

        for item in contents {
            if item.lowercased().contains(model.lowercased()) {
                let itemPath = modelFolder.appendingPathComponent(item)
                try? fm.removeItem(at: itemPath)
                logger.info("Deleted cached model: \(item)")
            }
        }
    }

    // MARK: - Model Loading

    func loadModel(_ model: String = Constants.WhisperModel.defaultModel) async {
        guard !modelState.isLoading else {
            logger.info("Model load already in progress, skipping")
            return
        }

        loadTask?.cancel()
        loadTask = Task {
            await loadModelWithRetry(model, attempt: 0)
        }
        await loadTask?.value
    }

    func cancelModelLoad() {
        loadTask?.cancel()
        loadTask = nil
        if modelState.isLoading {
            modelState = .notLoaded
            AppState.shared.modelState = .notLoaded
            logger.info("Model load cancelled")
        }
    }

    private func loadModelWithRetry(_ model: String, attempt: Int) async {
        guard !Task.isCancelled else { return }

        let cachedOnDisk = modelExistsOnDisk(model)

        if cachedOnDisk {
            // Model files exist locally - just need to load into memory
            modelState = .loading
            AppState.shared.modelState = .loading
            logger.info("Loading cached model '\(model)' from disk (attempt \(attempt + 1)/\(self.maxRetries + 1))")
        } else {
            // Need to download - check network first
            if !isNetworkAvailable {
                let message = "No internet connection. Connect to Wi-Fi or Ethernet to download the speech recognition model, then tap Retry."
                logger.error("Cannot download model '\(model)': no network connection")
                modelState = .error(message)
                AppState.shared.modelState = .error(message)
                return
            }
            modelState = .downloading(progress: 0.0)
            AppState.shared.modelState = .downloading(progress: 0.0)
            logger.info("Downloading model '\(model)' from Hugging Face (attempt \(attempt + 1)/\(self.maxRetries + 1))")
        }

        do {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let downloadFolder = appSupport.appendingPathComponent("Offline Speech to Text/Models")

            try? FileManager.default.createDirectory(at: downloadFolder, withIntermediateDirectories: true)

            logger.info("Model storage path: \(downloadFolder.path)")

            let config = WhisperKitConfig(
                model: model,
                downloadBase: downloadFolder,
                verbose: true,
                logLevel: .debug,
                prewarm: true,
                load: true,
                download: true
            )

            guard !Task.isCancelled else { return }

            whisperKit = try await WhisperKit(config)

            guard !Task.isCancelled else { return }

            modelState = .ready
            AppState.shared.modelState = .ready
            logger.info("Model '\(model)' loaded successfully and ready for transcription")
        } catch {
            guard !Task.isCancelled else { return }

            logger.error("Model '\(model)' loading failed: \(error.localizedDescription)")

            let errorString = error.localizedDescription.lowercased()
            let nsError = error as NSError

            let isNetworkError = errorString.contains("offline") ||
                                 errorString.contains("network") ||
                                 errorString.contains("internet") ||
                                 errorString.contains("connection") ||
                                 errorString.contains("timed out") ||
                                 errorString.contains("could not connect") ||
                                 errorString.contains("not connected") ||
                                 nsError.domain == NSURLErrorDomain

            let isMemoryError = errorString.contains("memory") ||
                                errorString.contains("allocation") ||
                                errorString.contains("resource")

            if isNetworkError && attempt < maxRetries {
                let delaySeconds = retryDelays[min(attempt, retryDelays.count - 1)]
                logger.info("Network error detected. Retrying in \(delaySeconds)s (attempt \(attempt + 1)/\(self.maxRetries))...")

                let retryMessage = "Network error. Retrying in \(delaySeconds)s (attempt \(attempt + 1)/\(self.maxRetries))..."
                modelState = .error(retryMessage)
                AppState.shared.modelState = .error(retryMessage)

                try? await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)

                guard !Task.isCancelled else { return }

                await loadModelWithRetry(model, attempt: attempt + 1)
            } else if isMemoryError {
                let message = "Not enough memory to load \(model). Please select a smaller model (e.g., tiny or base) in Settings."
                logger.error("Memory error loading model '\(model)'")
                modelState = .error(message)
                AppState.shared.modelState = .error(message)
            } else if isNetworkError {
                let message = "Download failed after \(maxRetries + 1) attempts. Please check your internet connection and try again."
                logger.error("All retry attempts exhausted for model '\(model)'")
                modelState = .error(message)
                AppState.shared.modelState = .error(message)
            } else {
                // For non-network, non-memory errors: could be corrupted cache
                if cachedOnDisk && attempt == 0 {
                    logger.warning("Model load failed with cached files. Deleting cache and retrying fresh download...")
                    deleteModelCache(model)
                    await loadModelWithRetry(model, attempt: attempt + 1)
                } else {
                    let message = "Failed to load model: \(error.localizedDescription)"
                    logger.error("Non-retryable error for model '\(model)': \(error.localizedDescription)")
                    modelState = .error(message)
                    AppState.shared.modelState = .error(message)
                }
            }
        }
    }

    // MARK: - Recording

    func startRecording() async {
        guard modelState.isReady, !isRecording else {
            logger.warning("Cannot start recording: modelState.isReady=\(self.modelState.isReady), isRecording=\(self.isRecording)")
            return
        }

        // Verify microphone permission before accessing audio hardware
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard audioStatus == .authorized else {
            logger.warning("Microphone permission not authorized: \(audioStatus.rawValue)")
            return
        }

        audioBufferLock.lock()
        audioBuffers.removeAll()
        audioBufferLock.unlock()
        currentTranscription = ""

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            logger.error("Failed to create AVAudioEngine")
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
            logger.error("Invalid hardware format: sampleRate=\(hardwareFormat.sampleRate), channels=\(hardwareFormat.channelCount)")
            self.audioEngine = nil
            return
        }

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            logger.error("Failed to create target audio format")
            self.audioEngine = nil
            return
        }

        guard let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat) else {
            logger.error("Failed to create audio converter from \(hardwareFormat) to \(targetFormat)")
            self.audioEngine = nil
            return
        }

        var tapCallCount = 0
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: hardwareFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            tapCallCount += 1
            if tapCallCount == 1 {
                logger.debug("Audio tap receiving data, buffer frameLength: \(buffer.frameLength)")
            }

            let ratio = targetFormat.sampleRate / hardwareFormat.sampleRate
            let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
            guard frameCount > 0,
                  let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else {
                if tapCallCount == 1 {
                    logger.warning("Failed to create converted buffer")
                }
                return
            }

            var error: NSError?
            var inputProvided = false
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                if inputProvided {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                inputProvided = true
                outStatus.pointee = .haveData
                return buffer
            }

            converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

            if let error = error {
                if tapCallCount == 1 {
                    logger.warning("Audio conversion error: \(error.localizedDescription)")
                }
                return
            }

            if let channelData = convertedBuffer.floatChannelData?[0] {
                let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(convertedBuffer.frameLength)))
                self.audioBufferLock.lock()
                self.audioBuffers.append(contentsOf: samples)
                self.audioBufferLock.unlock()

                // Calculate RMS audio level for visualization
                let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
                let rms = sqrt(sumOfSquares / Float(samples.count))
                // Normalize to 0-1 range (typical speech is around 0.01-0.1 RMS)
                let normalizedLevel = min(1.0, rms * 10)

                DispatchQueue.main.async {
                    self.audioLevel = normalizedLevel
                }
            }
        }

        do {
            try audioEngine.start()

            // Verify the engine is actually running
            guard audioEngine.isRunning else {
                logger.error("Audio engine started but is not running")
                inputNode.removeTap(onBus: 0)
                self.audioEngine = nil
                return
            }

            isRecording = true
            logger.info("Recording started successfully")
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
            inputNode.removeTap(onBus: 0)
            self.audioEngine = nil
        }
    }

    func stopRecording() async -> TranscriptionResult {
        guard isRecording else {
            logger.info("stopRecording called but not recording")
            return TranscriptionResult(text: "", isFinal: true)
        }

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false
        audioLevel = 0

        // Small delay to ensure all buffered audio samples are processed
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Thread-safe copy of audio buffers
        audioBufferLock.lock()
        let buffersCopy = audioBuffers
        audioBuffers.removeAll()
        audioBufferLock.unlock()

        let durationSeconds = Double(buffersCopy.count) / sampleRate
        logger.info("Audio buffers collected: \(buffersCopy.count) samples (\(String(format: "%.2f", durationSeconds))s)")

        guard !buffersCopy.isEmpty else {
            logger.warning("No audio data captured - audio engine may have failed to connect to microphone")
            return TranscriptionResult(text: "", isFinal: true)
        }

        let result = await transcribeAudio(buffersCopy)
        logger.info("Transcription result: '\(result.text)'")
        currentTranscription = result.text

        return result
    }

    private func transcribeAudio(_ samples: [Float]) async -> TranscriptionResult {
        guard let whisperKit = whisperKit else {
            logger.error("Transcription error: WhisperKit not initialized")
            return TranscriptionResult(text: "", isFinal: true)
        }

        // Validate audio has sufficient content
        let duration = Double(samples.count) / sampleRate
        logger.info("Transcribing \(samples.count) samples (\(String(format: "%.2f", duration))s)")

        if duration < 0.5 {
            logger.info("Audio too short for transcription (< 0.5s)")
            return TranscriptionResult(text: "", isFinal: true)
        }

        // Energy-based silence detection: compute RMS and skip if audio is essentially silent.
        // Whisper hallucinates common words (e.g. "you") when given near-silent audio.
        let sumOfSquares = samples.reduce(0.0) { $0 + Double($1) * Double($1) }
        let rms = sqrt(sumOfSquares / Double(samples.count))
        let silenceThreshold: Double = 0.001  // ~-60 dBFS
        if rms < silenceThreshold {
            logger.info("Audio RMS \(rms) below silence threshold — skipping transcription")
            return TranscriptionResult(text: "", isFinal: true)
        }

        do {
            let language = AppState.shared.selectedLanguage
            let languageToUse = language == "auto" ? nil : language
            logger.info("Using language: \(languageToUse ?? "auto-detect"), audio RMS: \(rms)")

            let options = DecodingOptions(
                verbose: false,
                task: .transcribe,
                language: languageToUse,
                temperatureFallbackCount: 3,
                sampleLength: 224,
                usePrefillPrompt: false,
                usePrefillCache: false,
                skipSpecialTokens: true,
                withoutTimestamps: true
            )

            let results = try await whisperKit.transcribe(
                audioArray: samples,
                decodeOptions: options
            )

            logger.info("Transcription returned \(results.count) segments")

            let fullText = results.map { $0.text }.joined(separator: " ")
            let trimmedText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)

            return TranscriptionResult(
                text: trimmedText,
                language: languageToUse,
                isFinal: true
            )
        } catch {
            logger.error("Transcription error: \(error.localizedDescription)")
            return TranscriptionResult(text: "", isFinal: true)
        }
    }

    func cancelRecording() {
        recordingTask?.cancel()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false
        audioLevel = 0
        audioBufferLock.lock()
        audioBuffers.removeAll()
        audioBufferLock.unlock()
        currentTranscription = ""
    }
}
