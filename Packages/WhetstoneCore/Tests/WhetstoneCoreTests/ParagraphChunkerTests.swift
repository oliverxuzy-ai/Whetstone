import XCTest
@testable import WhetstoneCore

final class ParagraphChunkerTests: XCTestCase {

    func testEmptyReturnsNoChunks() {
        XCTAssertTrue(ParagraphChunker.chunk([]).isEmpty)
    }

    func testGroupsByParagraphCount() {
        let paras = (0..<20).map { "p\($0)" }   // each tiny, so only count bounds
        let ranges = ParagraphChunker.chunk(paras, maxParagraphs: 8, maxChars: 100_000)
        XCTAssertEqual(ranges, [0..<8, 8..<16, 16..<20])
        // contiguous + total coverage
        XCTAssertEqual(ranges.flatMap { Array($0) }, Array(0..<20))
    }

    func testGroupsByCharBudget() {
        // each paragraph 100 chars, maxChars 250 → 2 per chunk (250 fits 2, 3rd overflows)
        let paras = Array(repeating: String(repeating: "x", count: 100), count: 5)
        let ranges = ParagraphChunker.chunk(paras, maxParagraphs: 100, maxChars: 250)
        XCTAssertEqual(ranges, [0..<2, 2..<4, 4..<5])
    }

    func testSingleOversizedParagraphGetsOwnChunk() {
        // one paragraph far exceeds maxChars — must still be its own chunk, never dropped
        let big = String(repeating: "y", count: 5000)
        let paras = ["small", big, "small2"]
        let ranges = ParagraphChunker.chunk(paras, maxParagraphs: 8, maxChars: 1500)
        XCTAssertEqual(ranges, [0..<1, 1..<2, 2..<3])
        XCTAssertEqual(ranges.flatMap { Array($0) }, [0, 1, 2])
    }

    func testFitsInSingleChunk() {
        let paras = ["a", "b", "c"]
        XCTAssertEqual(ParagraphChunker.chunk(paras), [0..<3])
    }
}
