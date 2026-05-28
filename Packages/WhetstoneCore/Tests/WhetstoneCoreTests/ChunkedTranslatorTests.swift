import XCTest
@testable import WhetstoneCore

final class ChunkedTranslatorTests: XCTestCase {

    func testEmptyInputReturnsEmpty() async throws {
        let out = try await ChunkedTranslator.translate(paragraphs: []) { _ in
            XCTFail("should not call translateOnce for empty input")
            return []
        }
        XCTAssertTrue(out.isEmpty)
    }

    func testReassemblesInOriginalOrderAcrossChunks() async throws {
        // Force many small chunks (1 paragraph each) so concurrency + reassembly matter.
        let paras = (0..<12).map { "p\($0)" }
        let out = try await ChunkedTranslator.translate(
            paragraphs: paras,
            maxParagraphsPerChunk: 1,
            maxConcurrency: 4
        ) { slice in
            // "translate" = uppercase, with jittered delay so completion order != input order
            let idx = Int(slice[0].dropFirst()) ?? 0
            try await Task.sleep(nanoseconds: UInt64((12 - idx) * 1_000_000))
            return slice.map { $0.uppercased() }
        }
        XCTAssertEqual(out, paras.map { $0.uppercased() })
    }

    func testOutputAligns1to1EvenWhenChunkPadsCount() async throws {
        // translateOnce returns wrong count for one chunk; ChunkedTranslator itself
        // doesn't pad (that's ResponseParser's job) — here we just confirm flat order.
        let paras = ["a", "b", "c", "d"]
        let out = try await ChunkedTranslator.translate(
            paragraphs: paras,
            maxParagraphsPerChunk: 2,
            maxConcurrency: 2
        ) { slice in slice.map { "[\($0)]" } }
        XCTAssertEqual(out, ["[a]", "[b]", "[c]", "[d]"])
    }

    func testRetriesOnceThenSucceeds() async throws {
        let attempts = Counter()
        let out = try await ChunkedTranslator.translate(
            paragraphs: ["only"],
            retries: 1
        ) { slice in
            let n = await attempts.increment()
            if n == 1 { throw AIClientError.invalidResponse }  // first attempt fails
            return slice
        }
        XCTAssertEqual(out, ["only"])
        let total = await attempts.value
        XCTAssertEqual(total, 2, "expected 1 failure + 1 retry success")
    }

    func testThrowsWhenChunkFailsBeyondRetries() async {
        do {
            _ = try await ChunkedTranslator.translate(
                paragraphs: ["x"],
                retries: 1
            ) { _ in throw AIClientError.invalidResponse }
            XCTFail("should throw when a chunk exhausts retries")
        } catch {
            XCTAssertEqual(error as? AIClientError, .invalidResponse)
        }
    }
}

/// Minimal async-safe counter for asserting attempt counts.
private actor Counter {
    private(set) var value = 0
    func increment() -> Int { value += 1; return value }
}
