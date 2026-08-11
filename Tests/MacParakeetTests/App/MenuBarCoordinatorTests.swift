import AppKit
import XCTest
@testable import MacParakeet
@testable import MacParakeetCore
@testable import MacParakeetViewModels

@MainActor
final class MenuBarCoordinatorTests: XCTestCase {
    func testVoiceFlowMenuBarStatesExposeExpectedAnimationFrames() {
        XCTAssertEqual(BreathWaveIcon.menuBarAnimationFrameCount(for: .idle), 1)
        XCTAssertEqual(BreathWaveIcon.menuBarAnimationFrameCount(for: .recording), 4)
        XCTAssertEqual(BreathWaveIcon.menuBarAnimationFrameCount(for: .processing), 4)
    }

    func testSpeechModelMenuEnablesOnlyDownloadedModelsAndKeepsCurrentModelAvailable() {
        let suite = "menu-models-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let engine = EngineSettingsViewModel(defaults: defaults)
        engine.downloadedParakeetVariants = []
        engine.downloadedNemotronVariants = [.multilingual1120]
        engine.nemotronModelStatus = .notLoaded
        engine.whisperModelStatus = .notLoaded
        engine.cohereModelStatus = .notDownloaded

        let rows = MenuBarCoordinator.speechModelMenuRows(engine: engine)

        XCTAssertEqual(rows.map(\.engine), [.parakeet, .nemotron, .whisper, .cohere])
        XCTAssertTrue(rows[0].isSelected)
        XCTAssertTrue(rows[0].isEnabled, "The already-loaded model must stay selectable")
        XCTAssertTrue(rows[1].isEnabled)
        XCTAssertTrue(rows[2].isEnabled)
        XCTAssertFalse(rows[3].isEnabled)
        XCTAssertTrue(rows[3].title.contains("Not downloaded"))
    }

    func testSpeechModelMenuDisablesSwitchesWhileRuntimeIsBusy() {
        let suite = "menu-models-busy-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let engine = EngineSettingsViewModel(defaults: defaults)
        engine.downloadedParakeetVariants = [.v3]
        engine.whisperModelStatus = .notLoaded
        engine.speechEngineSwitching = true

        XCTAssertTrue(
            MenuBarCoordinator.speechModelMenuRows(engine: engine).allSatisfy { !$0.isEnabled }
        )
    }

    func testMeetingRecordingMenuPresentationWhileIdle() {
        let presentation = MenuBarCoordinator.meetingRecordingMenuPresentation(
            environmentReady: true,
            isMeetingRecordingActive: false,
            canOpenLiveMeetingPanel: false
        )

        XCTAssertEqual(presentation.recordingTitle, "Start Recording")
        XCTAssertTrue(presentation.recordingEnabled)
        XCTAssertTrue(presentation.openLiveMeetingPanelHidden)
        XCTAssertFalse(presentation.openLiveMeetingPanelEnabled)
    }

    func testMeetingRecordingMenuPresentationWhileRecording() {
        let presentation = MenuBarCoordinator.meetingRecordingMenuPresentation(
            environmentReady: true,
            isMeetingRecordingActive: true,
            canOpenLiveMeetingPanel: true
        )

        XCTAssertEqual(presentation.recordingTitle, "Stop Recording")
        XCTAssertTrue(presentation.recordingEnabled)
        XCTAssertFalse(presentation.openLiveMeetingPanelHidden)
        XCTAssertTrue(presentation.openLiveMeetingPanelEnabled)
    }

    func testMeetingRecordingMenuPresentationDisablesActionsBeforeEnvironmentIsReady() {
        let presentation = MenuBarCoordinator.meetingRecordingMenuPresentation(
            environmentReady: false,
            isMeetingRecordingActive: true,
            canOpenLiveMeetingPanel: true
        )

        XCTAssertFalse(presentation.recordingEnabled)
        XCTAssertFalse(presentation.openLiveMeetingPanelEnabled)
    }

    func testMeetingRecordingMenuPresentationKeepsPanelActionDisabledUntilPanelExists() {
        let presentation = MenuBarCoordinator.meetingRecordingMenuPresentation(
            environmentReady: true,
            isMeetingRecordingActive: true,
            canOpenLiveMeetingPanel: false
        )

        XCTAssertFalse(presentation.openLiveMeetingPanelHidden)
        XCTAssertFalse(presentation.openLiveMeetingPanelEnabled)
    }
}
