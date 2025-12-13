import OptimusClipCore
import Testing

@Suite("ClipboardContentType Tests")
struct ClipboardContentTypeTests {
    // MARK: - isProcessable Tests

    @Test("Text type is processable")
    func textIsProcessable() {
        let type = ClipboardContentType.text
        #expect(type.isProcessable == true)
    }

    @Test("Binary type is not processable")
    func binaryIsNotProcessable() {
        let type = ClipboardContentType.binary(type: "public.png")
        #expect(type.isProcessable == false)
    }

    @Test("Empty type is not processable")
    func emptyIsNotProcessable() {
        let type = ClipboardContentType.empty
        #expect(type.isProcessable == false)
    }

    @Test("Unknown type is not processable")
    func unknownIsNotProcessable() {
        let type = ClipboardContentType.unknown
        #expect(type.isProcessable == false)
    }

    // MARK: - Friendly Description Tests

    @Test("Text has friendly description")
    func textFriendlyDescription() {
        let type = ClipboardContentType.text
        #expect(type.friendlyDescription == "text")
    }

    @Test("Empty has friendly description")
    func emptyFriendlyDescription() {
        let type = ClipboardContentType.empty
        #expect(type.friendlyDescription == "nothing")
    }

    @Test("Unknown has friendly description")
    func unknownFriendlyDescription() {
        let type = ClipboardContentType.unknown
        #expect(type.friendlyDescription == "unknown content")
    }

    // MARK: - Image Type Friendly Names

    @Test("PNG is described as image")
    func pngFriendlyName() {
        let description = ClipboardContentType.friendlyTypeName(for: "public.png")
        #expect(description == "an image")
    }

    @Test("JPEG is described as image")
    func jpegFriendlyName() {
        let description = ClipboardContentType.friendlyTypeName(for: "public.jpeg")
        #expect(description == "an image")
    }

    @Test("TIFF is described as image")
    func tiffFriendlyName() {
        let description = ClipboardContentType.friendlyTypeName(for: "public.tiff")
        #expect(description == "an image")
    }

    @Test("HEIC is described as image")
    func heicFriendlyName() {
        let description = ClipboardContentType.friendlyTypeName(for: "public.heic")
        #expect(description == "an image")
    }

    @Test("GIF is described as image")
    func gifFriendlyName() {
        let description = ClipboardContentType.friendlyTypeName(for: "public.gif")
        #expect(description == "an image")
    }

    @Test("WebP is described as image")
    func webpFriendlyName() {
        let description = ClipboardContentType.friendlyTypeName(for: "public.webp")
        #expect(description == "an image")
    }

    // MARK: - File Type Friendly Names

    @Test("File URL is described as file")
    func fileUrlFriendlyName() {
        let description = ClipboardContentType.friendlyTypeName(for: "public.file-url")
        #expect(description == "a file")
    }

    @Test("Finder node is described as file")
    func finderNodeFriendlyName() {
        let description = ClipboardContentType.friendlyTypeName(for: "com.apple.finder.node")
        #expect(description == "a file")
    }

    // MARK: - PDF Type Friendly Names

    @Test("Adobe PDF is described as PDF")
    func adobePdfFriendlyName() {
        let description = ClipboardContentType.friendlyTypeName(for: "com.adobe.pdf")
        #expect(description == "a PDF")
    }

    @Test("Public PDF is described as PDF")
    func publicPdfFriendlyName() {
        let description = ClipboardContentType.friendlyTypeName(for: "public.pdf")
        #expect(description == "a PDF")
    }

    // MARK: - Archive Type Friendly Names

    @Test("ZIP is described as archive")
    func zipFriendlyName() {
        let description = ClipboardContentType.friendlyTypeName(for: "public.zip-archive")
        #expect(description == "an archive")
    }

    // MARK: - Audio/Video Type Friendly Names

    @Test("Audio is described as audio")
    func audioFriendlyName() {
        let description = ClipboardContentType.friendlyTypeName(for: "public.audio")
        #expect(description == "audio")
    }

    @Test("Video is described as video")
    func videoFriendlyName() {
        let description = ClipboardContentType.friendlyTypeName(for: "public.movie")
        #expect(description == "video")
    }

    // MARK: - Unknown Type Fallback

    @Test("Unknown type has fallback description")
    func unknownTypeFriendlyName() {
        let description = ClipboardContentType.friendlyTypeName(for: "com.some.unknown.type")
        #expect(description == "non-text content")
    }

    // MARK: - Binary Type Friendly Description Integration

    @Test("Binary PNG has integrated friendly description")
    func binaryPngIntegratedDescription() {
        let type = ClipboardContentType.binary(type: "public.png")
        #expect(type.friendlyDescription == "an image")
    }

    @Test("Binary PDF has integrated friendly description")
    func binaryPdfIntegratedDescription() {
        let type = ClipboardContentType.binary(type: "com.adobe.pdf")
        #expect(type.friendlyDescription == "a PDF")
    }

    @Test("Binary file has integrated friendly description")
    func binaryFileIntegratedDescription() {
        let type = ClipboardContentType.binary(type: "public.file-url")
        #expect(type.friendlyDescription == "a file")
    }

    // MARK: - Equatable Tests

    @Test("Text types are equal")
    func textTypesEqual() {
        let type1 = ClipboardContentType.text
        let type2 = ClipboardContentType.text
        #expect(type1 == type2)
    }

    @Test("Empty types are equal")
    func emptyTypesEqual() {
        let type1 = ClipboardContentType.empty
        let type2 = ClipboardContentType.empty
        #expect(type1 == type2)
    }

    @Test("Binary types with same UTI are equal")
    func binaryTypesWithSameUtiEqual() {
        let type1 = ClipboardContentType.binary(type: "public.png")
        let type2 = ClipboardContentType.binary(type: "public.png")
        #expect(type1 == type2)
    }

    @Test("Binary types with different UTI are not equal")
    func binaryTypesWithDifferentUtiNotEqual() {
        let type1 = ClipboardContentType.binary(type: "public.png")
        let type2 = ClipboardContentType.binary(type: "public.jpeg")
        #expect(type1 != type2)
    }

    @Test("Different content types are not equal")
    func differentTypesNotEqual() {
        let text = ClipboardContentType.text
        let binary = ClipboardContentType.binary(type: "public.png")
        let empty = ClipboardContentType.empty
        let unknown = ClipboardContentType.unknown

        #expect(text != binary)
        #expect(text != empty)
        #expect(text != unknown)
        #expect(binary != empty)
        #expect(binary != unknown)
        #expect(empty != unknown)
    }

    // MARK: - CustomStringConvertible Tests

    @Test("Text has correct description")
    func textDescription() {
        let type = ClipboardContentType.text
        #expect(type.description == "ClipboardContentType.text")
    }

    @Test("Binary has correct description")
    func binaryDescription() {
        let type = ClipboardContentType.binary(type: "public.png")
        #expect(type.description == "ClipboardContentType.binary(public.png)")
    }

    @Test("Empty has correct description")
    func emptyDescription() {
        let type = ClipboardContentType.empty
        #expect(type.description == "ClipboardContentType.empty")
    }

    @Test("Unknown has correct description")
    func unknownDescription() {
        let type = ClipboardContentType.unknown
        #expect(type.description == "ClipboardContentType.unknown")
    }
}

// MARK: - ClipboardReadError Tests

@Suite("ClipboardReadError Tests")
struct ClipboardReadErrorTests {
    @Test("Empty error has correct message")
    func emptyErrorMessage() {
        let error = ClipboardReadError.empty
        #expect(error.message == "Clipboard is empty")
    }

    @Test("Binary content error includes type in message")
    func binaryErrorMessage() {
        let error = ClipboardReadError.binaryContent(type: "public.png")
        #expect(error.message.contains("an image"))
        #expect(error.message.contains("only text can be transformed"))
    }

    @Test("No text content error has correct message")
    func noTextErrorMessage() {
        let error = ClipboardReadError.noTextContent
        #expect(error.message == "Clipboard doesn't contain text")
    }

    @Test("Unknown content error has correct message")
    func unknownErrorMessage() {
        let error = ClipboardReadError.unknownContent
        #expect(error.message == "Clipboard contains unrecognized content")
    }

    @Test("Errors are equatable")
    func errorsEquatable() {
        #expect(ClipboardReadError.empty == ClipboardReadError.empty)
        #expect(ClipboardReadError.binaryContent(type: "public.png") == ClipboardReadError
            .binaryContent(type: "public.png"))
        #expect(ClipboardReadError.binaryContent(type: "public.png") != ClipboardReadError
            .binaryContent(type: "public.jpeg"))
    }
}
