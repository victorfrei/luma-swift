import Foundation

/// Cliente da API pública da Luma (/v1).
///
/// `getToken` devolve um token de service account (ou outro bearer aceito pela
/// API) válido. Não deixe o secret da service account no app: gere o token no
/// seu backend e entregue só o token, que expira.
public actor LumaSdk {
    private let apiUrl: String
    private let getToken: @Sendable () async throws -> String
    private let session: URLSession

    public init(
        apiUrl: String = "https://luma-api.geekapps.com.br",
        session: URLSession = URLSession(configuration: .default),
        getToken: @escaping @Sendable () async throws -> String
    ) {
        self.apiUrl = apiUrl.hasSuffix("/") ? String(apiUrl.dropLast()) : apiUrl
        self.session = session
        self.getToken = getToken
    }

    // MARK: - Base

    private func makeRequest(_ method: String, _ path: String, body: (any Encodable)? = nil) async throws -> URLRequest {
        guard let url = URL(string: "\(apiUrl)/v1\(path)") else { throw LumaSdkError(message: "URL inválida") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(try await getToken())", forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }
        return req
    }

    private static func fail(_ data: Data, _ status: Int) -> LumaSdkError {
        struct Envelope: Decodable {
            struct Err: Decodable { let message: String? }
            let error: Err?
        }
        let message = (try? JSONDecoder().decode(Envelope.self, from: data))?.error?.message
        return LumaSdkError(message: message ?? "HTTP \(status)", status: status)
    }

    private func send<T: Decodable>(_ method: String, _ path: String, body: (any Encodable)? = nil) async throws -> T {
        let req = try await makeRequest(method, path, body: body)
        let (data, res) = try await session.data(for: req)
        let status = (res as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw Self.fail(data, status) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Chat

    /// Resposta completa (sem streaming).
    public func chat(_ request: ChatRequest) async throws -> ChatCompletion {
        var r = request
        r.stream = false
        return try await send("POST", "/chat/completions", body: r)
    }

    /// Resposta em streaming: devolve os pedaços de texto conforme chegam.
    public nonisolated func chatStream(_ request: ChatRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var r = request
                    r.stream = true
                    let req = try await self.makeRequest("POST", "/chat/completions", body: r)
                    let (bytes, res) = try await self.session.bytes(for: req)
                    let status = (res as? HTTPURLResponse)?.statusCode ?? 0
                    guard (200..<300).contains(status) else {
                        var data = Data()
                        for try await byte in bytes { data.append(byte) }
                        throw Self.fail(data, status)
                    }
                    struct Chunk: Decodable {
                        struct Choice: Decodable {
                            struct Delta: Decodable { let content: String? }
                            let delta: Delta?
                        }
                        let choices: [Choice]?
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload.isEmpty { continue }
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(Chunk.self, from: data),
                              let text = chunk.choices?.first?.delta?.content, !text.isEmpty else { continue }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Atalho: texto completo da resposta.
    public func ask(_ request: ChatRequest) async throws -> String {
        try await chat(request).text
    }

    // MARK: - Embeddings / rerank

    public func embeddings(_ texts: [String]) async throws -> EmbeddingsResult {
        struct Body: Encodable { let input: [String] }
        return try await send("POST", "/embeddings", body: Body(input: texts))
    }

    public func rerank(query: String, documents: [String]) async throws -> RerankResult {
        struct Body: Encodable { let query: String; let documents: [String] }
        return try await send("POST", "/rerank", body: Body(query: query, documents: documents))
    }

    // MARK: - Imagem / vídeo

    /// Gera uma imagem e espera ficar pronta (pode levar alguns segundos).
    public func generateImage(_ options: ImageOptions) async throws -> ImageResult {
        try await send("POST", "/images/generations", body: options)
    }

    /// Começa a gerar um vídeo (leva minutos). Acompanhe com `video(id:)` ou `waitForVideo(id:)`.
    public func createVideo(prompt: String) async throws -> Video {
        struct Body: Encodable { let prompt: String }
        return try await send("POST", "/videos", body: Body(prompt: prompt))
    }

    public func video(id: String) async throws -> Video {
        try await send("GET", "/videos/\(id)")
    }

    /// Espera o vídeo terminar; lança erro se falhar ou passar de `timeout` (padrão 10 min).
    public func waitForVideo(id: String, interval: TimeInterval = 5, timeout: TimeInterval = 600) async throws -> Video {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            let v = try await video(id: id)
            if v.status == "completed" { return v }
            if v.status == "failed" { throw LumaSdkError(message: v.error?.message ?? "Falha ao gerar o vídeo") }
            if Date() >= deadline { throw LumaSdkError(message: "Tempo esgotado esperando o vídeo", status: 408) }
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }
}
