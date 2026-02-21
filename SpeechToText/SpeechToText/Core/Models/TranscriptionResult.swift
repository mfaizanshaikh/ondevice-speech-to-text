import Foundation

struct TranscriptionResult: Identifiable, Equatable {
    let id: UUID
    let text: String
    let language: String?
    let confidence: Double?
    let timestamp: Date
    let duration: TimeInterval?
    let isFinal: Bool
    let tooShort: Bool

    init(
        id: UUID = UUID(),
        text: String,
        language: String? = nil,
        confidence: Double? = nil,
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        isFinal: Bool = true,
        tooShort: Bool = false
    ) {
        self.id = id
        self.text = text
        self.language = language
        self.confidence = confidence
        self.timestamp = timestamp
        self.duration = duration
        self.isFinal = isFinal
        self.tooShort = tooShort
    }

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isEmpty: Bool {
        trimmedText.isEmpty
    }
}

struct TranscriptionSegment: Identifiable, Equatable {
    let id: UUID
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Double?

    init(
        id: UUID = UUID(),
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        confidence: Double? = nil
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
    }

    var duration: TimeInterval {
        endTime - startTime
    }
}
