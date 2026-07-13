@testable import Copyas
import FoundationModels
import XCTest

#if COPYAS_ENABLE_PCC
import TwoMillionKit
#endif

final class LiveModelClientTests: XCTestCase {
    #if COPYAS_ENABLE_PCC
    func testPrewarmIsNoOpForPrivateCloudComputeBackend() throws {
        try MacOSTestSupport.skipUnlessMacOS27()

        let backend = ModelBackend.privateCloudCompute(
            FMToolLanguageModel(
                model: .privateCloudCompute,
                executableURL: URL(fileURLWithPath: "/usr/bin/fm")
            )
        )
        let client = LiveModelClient(backend: backend)

        client.prewarm(transform: .summary)
        client.prewarmAllTransforms()
    }

    func testPrivateCloudComputeBackendEmitsBufferedPartialOutput() async throws {
        try MacOSTestSupport.skipUnlessMacOS27()

        let stub = try makeEchoStub()
        defer { try? FileManager.default.removeItem(at: stub.deletingLastPathComponent()) }

        let backend = ModelBackend.privateCloudCompute(
            FMToolLanguageModel(model: .system, executableURL: stub)
        )
        let client = LiveModelClient(backend: backend)

        var partials: [String] = []
        let output = try await client.generate(
            transform: .pirate,
            input: "Hello",
            onPartial: { partials.append($0) }
        )

        XCTAssertEqual(partials.count, 1)
        XCTAssertEqual(partials[0], output)
        XCTAssertTrue(output.contains("respond --model system --no-stream"))
    }
    #endif

    func testOnDeviceBackendSupportsStreamingFlag() throws {
        let backend = try ModelResolver.resolve(
            preference: .local,
            fmExecutableURL: URL(fileURLWithPath: "/definitely/missing/fm")
        )
        XCTAssertTrue(backend.supportsStreaming)
    }

    #if COPYAS_ENABLE_PCC
    private func makeEchoStub() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appendingPathComponent("echo-stub")
        try FileManager.default.createSymbolicLink(
            atPath: executable.path,
            withDestinationPath: "/bin/echo"
        )
        return executable
    }
    #endif
}
