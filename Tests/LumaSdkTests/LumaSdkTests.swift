import Testing
import Foundation
@testable import LumaSdk

@Suite("LumaSdk")
struct LumaSdkTests {
    @Test("ChatRequest encodes correctly")
    func chatRequestEncoding() throws {
        let req = ChatRequest(messages: [ChatMessage(role: "user", content: "Oi")], model: .fast, webSearch: true)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(req)) as! [String: Any]
        #expect(json["model"] as? String == "echo")
        #expect(json["web_search"] as? Bool == true)
        #expect(json["stream"] as? Bool == false)
    }

    @Test("ContentPart encodes in OpenAI format")
    func contentPartEncoding() throws {
        let text = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ContentPart.text("hello"))) as! [String: Any]
        #expect(text["type"] as? String == "text")
        #expect(text["text"] as? String == "hello")

        let image = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ContentPart.image(url: "https://example.com/img.jpg"))) as! [String: Any]
        #expect(image["type"] as? String == "image_url")
        #expect((image["image_url"] as? [String: String])?["url"] == "https://example.com/img.jpg")
    }

    @Test("Embeddings come back in input order")
    func embeddingsOrder() throws {
        let json = #"{"data":[{"embedding":[2],"index":1},{"embedding":[1],"index":0}],"model":"bge-m3"}"#
        let result = try JSONDecoder().decode(EmbeddingsResult.self, from: Data(json.utf8))
        #expect(result.vectors == [[1], [2]])
    }
}
