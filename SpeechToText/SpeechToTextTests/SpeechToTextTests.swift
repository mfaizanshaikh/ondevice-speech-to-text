import XCTest
@testable import SpeechToText

final class SpeechToTextTests: XCTestCase {
    func testTranscriptionResultCreation() {
        let result = TranscriptionResult(text: "Hello, world!")
        XCTAssertEqual(result.text, "Hello, world!")
        XCTAssertTrue(result.isFinal)
        XCTAssertFalse(result.isEmpty)
    }

    func testTranscriptionResultEmpty() {
        let result = TranscriptionResult(text: "")
        XCTAssertTrue(result.isEmpty)
    }

    func testTranscriptionResultTrimmed() {
        let result = TranscriptionResult(text: "  Hello, world!  ")
        XCTAssertEqual(result.trimmedText, "Hello, world!")
    }

    func testModelStateReady() {
        let state = ModelState.ready
        XCTAssertTrue(state.isReady)
        XCTAssertFalse(state.isLoading)
    }

    func testModelStateDownloading() {
        let state = ModelState.downloading(progress: 0.5)
        XCTAssertFalse(state.isReady)
        XCTAssertTrue(state.isLoading)
    }

    func testRecordingStateIdle() {
        let state = RecordingState.idle
        XCTAssertEqual(state.iconName, "mic")
    }

    func testRecordingStateRecording() {
        let state = RecordingState.recording
        XCTAssertEqual(state.iconName, "mic.fill")
    }
}
