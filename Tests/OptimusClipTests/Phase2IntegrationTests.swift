import Foundation
import OptimusClipCore
import Testing

// MARK: - Phase 2 Verification Tests

//
// ## Architecture Note
// The OptimusClip test target only links to OptimusClipCore (pure Swift logic).
// The Phase 2 components (ClipboardMonitor, SelfWriteMarker, ClipboardSafety,
// ClipboardWriter, PasteSimulator, AccessibilityPermissionManager,
// TransformationFlowCoordinator) are in the OptimusClip executable target
// because they require AppKit/macOS APIs.
//
// ## Testing Strategy
// - **OptimusClipCore**: Automated unit tests (this file)
// - **OptimusClip components**: Manual testing checklist (see MANUAL_TESTING.md)
//
// ## What IS Tested Here (OptimusClipCore):
// - ClipboardContentType: Content type classification and friendly descriptions
// - ClipboardReadResult/Error: Read result types and error messages
// - Transformation protocol: Core transformation abstractions
//
// ## What Requires Manual Testing (OptimusClip):
// - ClipboardMonitor: Polling, change detection, delegate callbacks
// - SelfWriteMarker: Marker read/write, infinite loop prevention
// - ClipboardSafety: Binary detection with real clipboard
// - ClipboardWriter: Write operations with marker
// - PasteSimulator: CGEvent paste simulation
// - AccessibilityPermissionManager: Permission checking
// - TransformationFlowCoordinator: End-to-end flow

// MARK: - ClipboardContentType Additional Tests

@Suite("ClipboardContentType Phase 2 Tests")
struct ClipboardContentTypePhase2Tests {
    // MARK: - Processable Logic Tests

    @Test("Only text type is processable")
    func onlyTextIsProcessable() {
        #expect(ClipboardContentType.text.isProcessable == true)
        #expect(ClipboardContentType.empty.isProcessable == false)
        #expect(ClipboardContentType.unknown.isProcessable == false)
        #expect(ClipboardContentType.binary(type: "any").isProcessable == false)
    }

    @Test("Binary types with various UTIs are not processable")
    func binaryTypesNotProcessable() {
        let binaryTypes = [
            ClipboardContentType.binary(type: "public.png"),
            ClipboardContentType.binary(type: "public.jpeg"),
            ClipboardContentType.binary(type: "com.adobe.pdf"),
            ClipboardContentType.binary(type: "public.file-url"),
            ClipboardContentType.binary(type: "public.tiff")
        ]

        for type in binaryTypes {
            #expect(type.isProcessable == false, "Binary type \(type) should not be processable")
        }
    }

    // MARK: - Type Constants Tests

    @Test("Image types set contains common formats")
    func imageTypesSetComplete() {
        let imageTypes = ClipboardContentType.imageTypes
        #expect(imageTypes.contains("public.png"))
        #expect(imageTypes.contains("public.jpeg"))
        #expect(imageTypes.contains("public.tiff"))
        #expect(imageTypes.contains("public.heic"))
        #expect(imageTypes.contains("public.gif"))
        #expect(imageTypes.contains("public.webp"))
    }

    @Test("File types set contains common formats")
    func fileTypesSetComplete() {
        let fileTypes = ClipboardContentType.fileTypes
        #expect(fileTypes.contains("public.file-url"))
        #expect(fileTypes.contains("com.apple.finder.node"))
    }

    @Test("Archive types set exists")
    func archiveTypesExist() {
        let archiveTypes = ClipboardContentType.archiveTypes
        #expect(archiveTypes.contains("public.zip-archive"))
    }

    @Test("Audio types set exists")
    func audioTypesExist() {
        let audioTypes = ClipboardContentType.audioTypes
        #expect(audioTypes.contains("public.audio"))
    }

    @Test("Video types set exists")
    func videoTypesExist() {
        let videoTypes = ClipboardContentType.videoTypes
        #expect(videoTypes.contains("public.movie"))
        #expect(videoTypes.contains("public.video"))
    }

    // MARK: - Friendly Name Resolution Tests

    @Test("All image types resolve to 'an image'")
    func allImageTypesResolveFriendly() {
        for type in ClipboardContentType.imageTypes {
            let name = ClipboardContentType.friendlyTypeName(for: type)
            #expect(name == "an image", "\(type) should resolve to 'an image'")
        }
    }

    @Test("All file types resolve to 'a file'")
    func allFileTypesResolveFriendly() {
        for type in ClipboardContentType.fileTypes {
            let name = ClipboardContentType.friendlyTypeName(for: type)
            #expect(name == "a file", "\(type) should resolve to 'a file'")
        }
    }

    @Test("PDF types resolve correctly")
    func pdfTypesResolveFriendly() {
        #expect(ClipboardContentType.friendlyTypeName(for: "com.adobe.pdf") == "a PDF")
        #expect(ClipboardContentType.friendlyTypeName(for: "public.pdf") == "a PDF")
    }

    @Test("All archive types resolve to 'an archive'")
    func allArchiveTypesResolveFriendly() {
        for type in ClipboardContentType.archiveTypes {
            let name = ClipboardContentType.friendlyTypeName(for: type)
            #expect(name == "an archive", "\(type) should resolve to 'an archive'")
        }
    }

    @Test("All audio types resolve to 'audio'")
    func allAudioTypesResolveFriendly() {
        for type in ClipboardContentType.audioTypes {
            let name = ClipboardContentType.friendlyTypeName(for: type)
            #expect(name == "audio", "\(type) should resolve to 'audio'")
        }
    }

    @Test("All video types resolve to 'video'")
    func allVideoTypesResolveFriendly() {
        for type in ClipboardContentType.videoTypes {
            let name = ClipboardContentType.friendlyTypeName(for: type)
            #expect(name == "video", "\(type) should resolve to 'video'")
        }
    }

    @Test("Unknown types fall back to 'non-text content'")
    func unknownTypesFallback() {
        let unknownTypes = [
            "com.custom.unknown",
            "totally.random.type",
            "x.y.z"
        ]

        for type in unknownTypes {
            let name = ClipboardContentType.friendlyTypeName(for: type)
            #expect(name == "non-text content", "\(type) should fall back to 'non-text content'")
        }
    }

    // MARK: - Friendly Description Integration

    @Test("Binary content friendly description uses friendlyTypeName")
    func binaryFriendlyDescriptionIntegration() {
        // Verify that binary type's friendlyDescription matches friendlyTypeName
        let pngType = ClipboardContentType.binary(type: "public.png")
        #expect(pngType.friendlyDescription == ClipboardContentType.friendlyTypeName(for: "public.png"))

        let pdfType = ClipboardContentType.binary(type: "com.adobe.pdf")
        #expect(pdfType.friendlyDescription == ClipboardContentType.friendlyTypeName(for: "com.adobe.pdf"))
    }
}

// MARK: - ClipboardReadError Additional Tests

@Suite("ClipboardReadError Phase 2 Tests")
struct ClipboardReadErrorPhase2Tests {
    @Test("Binary content error message includes friendly type name")
    func binaryErrorIncludesFriendlyName() {
        let pngError = ClipboardReadError.binaryContent(type: "public.png")
        #expect(pngError.message.contains("an image"))

        let pdfError = ClipboardReadError.binaryContent(type: "com.adobe.pdf")
        #expect(pdfError.message.contains("a PDF"))

        let fileError = ClipboardReadError.binaryContent(type: "public.file-url")
        #expect(fileError.message.contains("a file"))
    }

    @Test("All error messages are non-empty")
    func allErrorMessagesNonEmpty() {
        let errors: [ClipboardReadError] = [
            .empty,
            .binaryContent(type: "public.png"),
            .noTextContent,
            .unknownContent
        ]

        for error in errors {
            #expect(!error.message.isEmpty, "\(error) should have non-empty message")
        }
    }

    @Test("Error messages are user-friendly (no technical jargon)")
    func errorMessagesUserFriendly() {
        // Messages should be understandable by non-technical users
        let emptyMessage = ClipboardReadError.empty.message
        #expect(emptyMessage.lowercased().contains("empty") || emptyMessage.lowercased().contains("nothing"))

        let binaryMessage = ClipboardReadError.binaryContent(type: "public.png").message
        #expect(binaryMessage.contains("only text"))

        let noTextMessage = ClipboardReadError.noTextContent.message
        #expect(noTextMessage.lowercased().contains("text"))
    }
}

// MARK: - ClipboardReadResult Tests

@Suite("ClipboardReadResult Phase 2 Tests")
struct ClipboardReadResultPhase2Tests {
    @Test("Success result contains text")
    func successContainsText() {
        let result = ClipboardReadResult.success("Hello World")
        if case let .success(text) = result {
            #expect(text == "Hello World")
        } else {
            Issue.record("Expected success case")
        }
    }

    @Test("Failure result contains error")
    func failureContainsError() {
        let result = ClipboardReadResult.failure(.empty)
        if case let .failure(error) = result {
            #expect(error == .empty)
        } else {
            Issue.record("Expected failure case")
        }
    }

    @Test("Can pattern match on success")
    func canPatternMatchSuccess() {
        let result = ClipboardReadResult.success("test")
        switch result {
        case let .success(text):
            #expect(text == "test")
        case .failure:
            Issue.record("Should be success")
        }
    }

    @Test("Can pattern match on failure")
    func canPatternMatchFailure() {
        let result = ClipboardReadResult.failure(.binaryContent(type: "public.png"))
        switch result {
        case .success:
            Issue.record("Should be failure")
        case let .failure(error):
            if case let .binaryContent(type) = error {
                #expect(type == "public.png")
            } else {
                Issue.record("Should be binaryContent error")
            }
        }
    }
}

// MARK: - Transformation Protocol Tests

@Suite("Transformation Protocol Phase 2 Tests")
struct TransformationProtocolPhase2Tests {
    @Test("IdentityTransformation returns input unchanged")
    func identityTransformationWorks() async throws {
        let transform = IdentityTransformation()
        let input = "Hello World"
        let output = try await transform.transform(input)
        #expect(output == input)
    }

    @Test("IdentityTransformation throws on empty string")
    func identityTransformationEmptyString() async throws {
        let transform = IdentityTransformation()
        do {
            _ = try await transform.transform("")
            Issue.record("Should throw emptyInput error for empty string")
        } catch let error as TransformationError {
            if case .emptyInput = error {
                // Expected behavior
            } else {
                Issue.record("Should throw emptyInput error, got: \(error)")
            }
        }
    }

    @Test("IdentityTransformation handles special characters")
    func identityTransformationSpecialChars() async throws {
        let transform = IdentityTransformation()
        let input = "Hello 👋 World 🌍\n\tSpecial: <>\"'&"
        let output = try await transform.transform(input)
        #expect(output == input)
    }

    @Test("IdentityTransformation handles unicode")
    func identityTransformationUnicode() async throws {
        let transform = IdentityTransformation()
        let input = "日本語 中文 한국어 العربية"
        let output = try await transform.transform(input)
        #expect(output == input)
    }

    @Test("IdentityTransformation handles very long text")
    func identityTransformationLongText() async throws {
        let transform = IdentityTransformation()
        let input = String(repeating: "a", count: 100_000)
        let output = try await transform.transform(input)
        #expect(output == input)
        #expect(output.count == 100_000)
    }
}

// MARK: - TransformationError Tests

@Suite("TransformationError Phase 2 Tests")
struct TransformationErrorPhase2Tests {
    @Test("Timeout error exists with seconds")
    func timeoutErrorExists() {
        let error = TransformationError.timeout(seconds: 30)
        // Verify it can be created and pattern matched
        if case let .timeout(seconds) = error {
            #expect(seconds == 30)
        } else {
            Issue.record("Should be timeout case")
        }
    }

    @Test("Network error exists with associated value")
    func networkErrorExists() {
        let error = TransformationError.networkError("Connection failed")
        if case let .networkError(message) = error {
            #expect(message == "Connection failed")
        } else {
            Issue.record("Should be networkError case")
        }
    }

    @Test("Authentication error exists")
    func authenticationErrorExists() {
        let error = TransformationError.authenticationError
        if case .authenticationError = error {
            // Expected
        } else {
            Issue.record("Should be authenticationError case")
        }
    }

    @Test("Processing error exists with message")
    func processingErrorExists() {
        let error = TransformationError.processingError("Something went wrong")
        if case let .processingError(message) = error {
            #expect(message == "Something went wrong")
        } else {
            Issue.record("Should be processingError case")
        }
    }

    @Test("Empty input error exists")
    func emptyInputErrorExists() {
        let error = TransformationError.emptyInput
        if case .emptyInput = error {
            // Expected
        } else {
            Issue.record("Should be emptyInput case")
        }
    }

    @Test("All error cases are defined")
    func allErrorCasesDefined() {
        // Verify we can create all error cases
        let errors: [TransformationError] = [
            .emptyInput,
            .timeout(seconds: 30),
            .networkError("test"),
            .authenticationError,
            .processingError("test"),
            .rateLimited(retryAfter: 60),
            .contentTooLarge(bytes: 1000, limit: 500)
        ]
        #expect(errors.count == 7)
    }
}

// MARK: - Phase 2 Manual Testing Checklist Documentation

/*
 ## Manual Testing Checklist for Phase 2 Components

 These tests must be performed manually because they require actual macOS system
 interactions that cannot be automated in unit tests.

 ### Prerequisites
 - macOS 15+ with Accessibility permission granted to the app
 - Multiple apps open for paste testing (TextEdit, Safari, Terminal)

 ### 1. ClipboardMonitor Tests
 □ Start monitoring, copy text in another app → delegate receives callback
 □ Monitor detects change within 150ms of copy
 □ Grace delay (80ms) allows promised data to resolve
 □ Monitor correctly reads text from TextEdit, Terminal, Safari
 □ Suspend pauses monitoring, resume restarts it
 □ CPU usage stays below 1% while monitoring

 ### 2. SelfWriteMarker Tests
 □ Write with marker → hasMarker() returns true
 □ Write with marker → isSafeToProcess() returns false
 □ External copy → hasMarker() returns false
 □ External copy → isSafeToProcess() returns true
 □ Paste marked content into other apps → pastes correctly

 ### 3. ClipboardSafety Tests
 □ Copy text → detectContentType() returns .text
 □ Copy image (screenshot) → detectContentType() returns .binary
 □ Copy file in Finder → detectContentType() returns .binary
 □ Copy PDF → detectContentType() returns .binary
 □ Clear clipboard → detectContentType() returns .empty

 ### 4. ClipboardWriter Tests
 □ Write text → text appears on clipboard
 □ Write text → marker is present
 □ isWriting flag clears after ~200ms

 ### 5. PasteSimulator Tests
 □ With accessibility permission → paste works in TextEdit
 □ With accessibility permission → paste works in Safari
 □ With accessibility permission → paste works in Terminal
 □ Without accessibility permission → paste fails silently

 ### 6. AccessibilityPermissionManager Tests
 □ Initial state matches AXIsProcessTrusted()
 □ requestPermission() shows system dialog
 □ openSystemSettings() opens correct pane
 □ Polling detects when permission is granted

 ### 7. TransformationFlowCoordinator Tests
 □ Full flow: copy text → hotkey → transform → paste works
 □ Self-write marker prevents reprocessing
 □ Binary content is rejected with error
 □ Empty clipboard is rejected with error
 □ Concurrent hotkey presses are rejected
 □ Error states show appropriate error messages

 ### 8. End-to-End Integration Tests
 □ Copy "hello" → press hotkey → "hello" (identity) pasted
 □ Copy image → press hotkey → nothing happens (correct)
 □ Copy file → press hotkey → nothing happens (correct)
 □ Transform once → press hotkey again → no double transform
 □ Rapid hotkey presses → no crashes

 ### Performance Tests
 □ Clipboard monitoring for 10 minutes → no performance degradation
 □ 100 consecutive transformations → no memory leaks
 □ Transformation latency under 200ms (with identity transform)
 */
