import XCTest
@testable import Copyas

final class CopyasAppTests: XCTestCase {
    func testEmptyAppReturnsSuccess() async {
        let environment = AppEnvironment(
            writeStdout: { _ in },
            writeStderr: { _ in }
        )

        let exitCode = await CopyasApp.run(environment: environment)
        XCTAssertEqual(exitCode, 0)
    }
}
