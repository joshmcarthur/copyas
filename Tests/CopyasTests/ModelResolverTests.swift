@testable import Copyas
import XCTest

final class ModelResolverTests: XCTestCase {
    func testLocalReturnsOnDeviceBackend() throws {
        let backend = try ModelResolver.resolve(
            preference: .local,
            fmExecutableURL: URL(fileURLWithPath: "/definitely/missing/fm")
        )

        if case .onDevice = backend {
            XCTAssertTrue(backend.supportsStreaming)
        } else {
            XCTFail("Expected on-device backend")
        }
    }

    func testCloudThrowsWhenFMExecutableMissing() {
        XCTAssertThrowsError(
            try ModelResolver.resolve(
                preference: .cloud,
                fmExecutableURL: URL(fileURLWithPath: "/definitely/missing/fm")
            )
        ) { error in
            XCTAssertEqual(error as? GenerationError, .cloudModelUnavailable)
        }
    }

    #if COPYAS_ENABLE_PCC
    func testCloudReturnsPrivateCloudComputeWhenFMExists() throws {
        let stub = try makeExecutableStub()
        defer { try? FileManager.default.removeItem(at: stub.deletingLastPathComponent()) }

        let backend = try ModelResolver.resolve(preference: .cloud, fmExecutableURL: stub)

        if case .privateCloudCompute = backend {
            XCTAssertFalse(backend.supportsStreaming)
        } else {
            XCTFail("Expected Private Cloud Compute backend")
        }
    }

    func testAutomaticPrefersCloudWhenFMExists() throws {
        let stub = try makeExecutableStub()
        defer { try? FileManager.default.removeItem(at: stub.deletingLastPathComponent()) }

        let backend = try ModelResolver.resolve(preference: .automatic, fmExecutableURL: stub)

        if case .privateCloudCompute = backend {
            XCTAssertFalse(backend.supportsStreaming)
        } else {
            XCTFail("Expected Private Cloud Compute backend")
        }
    }
    #endif

    func testAutomaticFallsBackToLocalWhenFMMissing() throws {
        let backend = try ModelResolver.resolve(
            preference: .automatic,
            fmExecutableURL: URL(fileURLWithPath: "/definitely/missing/fm")
        )

        if case .onDevice = backend {
            XCTAssertTrue(backend.supportsStreaming)
        } else {
            XCTFail("Expected on-device backend")
        }
    }

    private func makeExecutableStub() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appendingPathComponent("fm-stub")
        try "#!/bin/sh\necho fm-stub\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )
        return executable
    }
}
