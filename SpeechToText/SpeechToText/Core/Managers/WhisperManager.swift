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
    private var recordingTask: Task<Void, Never>?

    private let sampleRate: Double = 16000
    private let bufferSize: AVAudioFrameCount = 1024

    private init() {}

    func loadModel(_ model: String = Constants.WhisperModel.defaultModel) async {
        guard !modelState.isLoading else { return }

        modelState = .downloading(progress: 0.0)
        AppState.shared.modelState = .downloading(progress: 0.0)
        print("Loading WhisperKit model: \(model)")

        do {
            let config = WhisperKitConfig(
                model: model,
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
            modelState = .error(error.localizedDescription)
            AppState.shared.modelState = .error(error.localizedDescription)
        }
    }

    func startRecording() async {
        guard modelState.isReady, !isRecording else {
            print("Cannot start recording: modelState.isReady=\(modelState.isReady), isRecording=\(isRecording)")
            return
        }

        audioBuffers.removeAll()
        currentTranscription = ""

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            print("Failed to create AVAudioEngine")
            return
        }

        let inputNode = audioEngine.inputNode

        // Prepare the engine first to ensure hardware is ready
        audioEngine.prepare()

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

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: hardwareFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            let ratio = targetFormat.sampleRate / hardwareFormat.sampleRate
            let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
            guard frameCount > 0,
                  let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else { return }

            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

            if error == nil, let channelData = convertedBuffer.floatChannelData?[0] {
                let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(convertedBuffer.frameLength)))
                Task { @MainActor in
                    self.audioBuffers.append(contentsOf: samples)
                }
            }
        }

        do {
            try audioEngine.start()
            isRecording = true
            print("Recording started successfully")
        } catch {
            print("Failed to start audio engine: \(error)")
            inputNode.removeTap(onBus: 0)
            self.audioEngine = nil
        }
    }

    func stopRecording() async -> TranscriptionResult {
        guard isRecording else {
            return TranscriptionResult(text: "", isFinal: true)
        }

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false

        guard !audioBuffers.isEmpty else {
            return TranscriptionResult(text: "", isFinal: true)
        }

        let result = await transcribeAudio(audioBuffers)
        currentTranscription = result.text
        audioBuffers.removeAll()

        return result
    }

    private func transcribeAudio(_ samples: [Float]) async -> TranscriptionResult {
        guard let whisperKit = whisperKit else {
            return TranscriptionResult(text: "", isFinal: true)
        }

        do {
            let language = AppState.shared.selectedLanguage
            let languageToUse = language == "auto" ? nil : language

            let options = DecodingOptions(
                verbose: false,
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

            let fullText = results.map { $0.text }.joined(separator: " ")
            let trimmedText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)

            return TranscriptionResult(
                text: trimmedText,
                language: languageToUse,
                isFinal: true
            )
        } catch {
            return TranscriptionResult(text: "", isFinal: true)
        }
    }

    func cancelRecording() {
        recordingTask?.cancel()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false
        audioBuffers.removeAll()
        currentTranscription = ""
    }
}
