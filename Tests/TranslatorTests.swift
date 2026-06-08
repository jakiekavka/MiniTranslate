import XCTest
@testable import MiniTranslate

final class MockURLProtocol: URLProtocol {
    static var mockResponse: ((URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let handler = MockURLProtocol.mockResponse,
              let client = client else { return }

        let (statusCode, data) = handler(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "1.1",
            headerFields: nil
        )!
        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(self, didLoad: data)
        client.urlProtocolDidFinishLoading(self)
    }
}

final class TranslatorTests: XCTestCase {
    private var session: URLSession!
    private var translator: Translator!

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
    }

    func testTranslateValidResponse() async throws {
        MockURLProtocol.mockResponse = { _ in
            let json = #"{"translations":[{"text":"你好","detected_source_language":"EN"}]}"#
            return (200, json.data(using: .utf8)!)
        }
        translator = Translator(apiKey: "test-key", session: session)
        let result = try await translator.translate(text: "Hello", from: .auto, to: .chinese)
        XCTAssertEqual(result, "你好")
    }

    func testTranslateInvalidKey() async {
        MockURLProtocol.mockResponse = { _ in (403, Data()) }
        translator = Translator(apiKey: "bad-key", session: session)
        do {
            _ = try await translator.translate(text: "Hello", from: .auto, to: .chinese)
            XCTFail("Expected invalidKey error")
        } catch DeepLError.invalidKey {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranslateRateLimited() async {
        MockURLProtocol.mockResponse = { _ in (429, Data()) }
        translator = Translator(apiKey: "test-key", session: session)
        do {
            _ = try await translator.translate(text: "Hello", from: .auto, to: .chinese)
            XCTFail("Expected rateLimited error")
        } catch DeepLError.rateLimited {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranslateEmptyText() async throws {
        MockURLProtocol.mockResponse = { _ in
            XCTFail("Should not make request for empty text")
            return (200, Data())
        }
        translator = Translator(apiKey: "test-key", session: session)
        let result = try await translator.translate(text: "", from: .auto, to: .chinese)
        XCTAssertEqual(result, "")
    }

    func testLanguageCodeMapping() {
        XCTAssertNil(Language.auto.deepLCode)
        XCTAssertEqual(Language.english.deepLCode, "EN")
        XCTAssertEqual(Language.chinese.deepLCode, "ZH")
        XCTAssertEqual(Language.korean.deepLCode, "KO")
    }

    func testLanguageIsTargetable() {
        XCTAssertFalse(Language.auto.isTargetable)
        XCTAssertTrue(Language.english.isTargetable)
        XCTAssertTrue(Language.chinese.isTargetable)
        XCTAssertTrue(Language.korean.isTargetable)
    }
}
