import Foundation

public enum ModelId: String, Codable, Sendable {
    case fast = "echo"
    case thinking = "nova"
    case deep = "atlas"
}

public enum MediaType: String, Codable, Sendable {
    case image, audio, video, document
}

/// Parte de uma mensagem, no formato OpenAI (texto, image_url, audio_url...).
public struct ContentPart: Encodable, Sendable {
    public var type: String
    public var text: String?
    public var url: String?
    public var mimeType: String?

    public init(type: String, text: String? = nil, url: String? = nil, mimeType: String? = nil) {
        self.type = type; self.text = text; self.url = url; self.mimeType = mimeType
    }

    public static func text(_ value: String) -> ContentPart { ContentPart(type: "text", text: value) }
    public static func image(url: String, mimeType: String = "image/jpeg") -> ContentPart {
        ContentPart(type: "image", url: url, mimeType: mimeType)
    }
    public static func audio(url: String, mimeType: String = "audio/mp4") -> ContentPart {
        ContentPart(type: "audio", url: url, mimeType: mimeType)
    }
    public static func video(url: String, mimeType: String = "video/mp4") -> ContentPart {
        ContentPart(type: "video", url: url, mimeType: mimeType)
    }

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ s: String) { stringValue = s }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        if type == "text" {
            try c.encode("text", forKey: Key("type"))
            try c.encode(text ?? "", forKey: Key("text"))
            return
        }
        let name = "\(type)_url"
        try c.encode(name, forKey: Key("type"))
        var media: [String: String] = ["url": url ?? ""]
        if type != "image", let mimeType { media["mime_type"] = mimeType }
        try c.encode(media, forKey: Key(name))
    }
}

public enum MessageContent: Encodable, Sendable {
    case text(String)
    case parts([ContentPart])

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let s): try container.encode(s)
        case .parts(let p): try container.encode(p)
        }
    }
}

public struct ChatMessage: Encodable, Sendable {
    public var role: String
    public var content: MessageContent

    public init(role: String, content: String) {
        self.role = role
        self.content = .text(content)
    }

    public init(role: String, parts: [ContentPart]) {
        self.role = role
        self.content = .parts(parts)
    }
}

public struct ChatRequest: Encodable, Sendable {
    public var messages: [ChatMessage]
    public var model: ModelId
    public var webSearch: Bool
    public var temperature: Double?
    public var maxTokens: Int?
    /// Continua uma conversa existente (extensão da Luma ao formato OpenAI).
    public var conversationId: String?
    var stream: Bool = false

    enum CodingKeys: String, CodingKey {
        case messages, model, temperature, stream
        case webSearch = "web_search"
        case maxTokens = "max_tokens"
        case conversationId = "conversation_id"
    }

    public init(
        messages: [ChatMessage],
        model: ModelId = .fast,
        webSearch: Bool = true,
        conversationId: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.messages = messages
        self.model = model
        self.webSearch = webSearch
        self.conversationId = conversationId
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

public struct Usage: Decodable, Sendable {
    public let promptTokens: Int?
    public let completionTokens: Int?
    public let totalTokens: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

public struct ChatCompletion: Decodable, Sendable {
    public struct Choice: Decodable, Sendable {
        public struct Message: Decodable, Sendable {
            public let role: String
            public let content: String?
        }
        public let index: Int
        public let message: Message
        public let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }

    public let id: String
    public let model: String
    public let choices: [Choice]
    public let usage: Usage?

    /// O texto da primeira resposta.
    public var text: String { choices.first?.message.content ?? "" }
}

public struct LumaSdkError: Error, LocalizedError, Sendable {
    public let message: String
    public var status: Int?
    public var errorDescription: String? { message }
}

// MARK: - Embeddings / rerank

public struct EmbeddingsResult: Decodable, Sendable {
    public struct Item: Decodable, Sendable {
        public let embedding: [Double]
        public let index: Int
    }
    public let data: [Item]
    public let model: String
    public let usage: Usage?

    /// Os vetores na ordem dos textos enviados.
    public var vectors: [[Double]] { data.sorted { $0.index < $1.index }.map(\.embedding) }
}

public struct RerankResult: Decodable, Sendable {
    public struct Item: Decodable, Sendable {
        public let index: Int
        public let relevanceScore: Double
        enum CodingKeys: String, CodingKey {
            case index
            case relevanceScore = "relevance_score"
        }
    }
    public let model: String
    public let results: [Item]
}

// MARK: - Imagem / vídeo

public enum ImageSize: String, Encodable, Sendable {
    case square = "1024x1024"
    case portrait = "1024x1536"
    case landscape = "1536x1024"
    case qhd = "2560x1440"
    case uhd = "3840x2160"
}

public enum ImageQuality: String, Encodable, Sendable {
    case low, medium, high
}

public struct ImageOptions: Encodable, Sendable {
    public var prompt: String
    public var size: ImageSize?
    public var quality: ImageQuality?
    public init(prompt: String, size: ImageSize? = nil, quality: ImageQuality? = nil) {
        self.prompt = prompt; self.size = size; self.quality = quality
    }
}

public struct ImageResult: Decodable, Sendable {
    public struct Item: Decodable, Sendable {
        public let url: String
        public let mimeType: String?
        enum CodingKeys: String, CodingKey {
            case url
            case mimeType = "mime_type"
        }
    }
    public let data: [Item]
    public var url: String? { data.first?.url }
}

public struct Video: Decodable, Sendable {
    public struct Failure: Decodable, Sendable { public let message: String }
    public let id: String
    /// queued, in_progress, completed ou failed.
    public let status: String
    public let url: String?
    public let mimeType: String?
    public let error: Failure?

    enum CodingKeys: String, CodingKey {
        case id, status, url, error
        case mimeType = "mime_type"
    }
}
