# Luma SDK for Swift

SDK Swift da API pública da Luma (`/v1`). iOS 16+, macOS 13+ e tvOS 16+.

## Instalação

Em Xcode: **File → Add Package Dependencies**, ou no `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/victorfrei/luma-swift", from: "2.0.0")
],
targets: [.target(name: "YourApp", dependencies: ["LumaSdk"])]
```

## Autenticação

A API usa o token de uma **service account** (Configurações → API no app da Luma). O SDK recebe
uma função que devolve o token válido; ela é chamada a cada requisição, então é o lugar de
renovar quando expirar.

> Não coloque o Client Secret dentro de um app. Troque o secret pelo token no seu backend
> (`POST https://accounts-api.geekapps.com.br/auth/token`) e entregue só o token ao app.
> Em Swift no servidor, pode trocar direto.

```swift
import LumaSdk

let luma = LumaSdk(getToken: { try await meuBackend.tokenDaLuma() })
```

`apiUrl` é opcional (padrão `https://luma-api.geekapps.com.br`).

## Chat

```swift
let texto = try await luma.ask(ChatRequest(
    messages: [ChatMessage(role: "user", content: "Olá! Como você pode me ajudar?")]
))
```

Com streaming:

```swift
for try await pedaco in luma.chatStream(ChatRequest(messages: messages, model: .thinking)) {
    print(pedaco, terminator: "")
}
```

`chat(_:)` devolve a resposta completa (`ChatCompletion`, com `usage`). Com imagens:

```swift
let parts: [ContentPart] = [.text("O que tem nessa imagem?"), .image(url: "https://.../foto.jpg")]
let r = try await luma.ask(ChatRequest(messages: [ChatMessage(role: "user", parts: parts)]))
```

Para continuar uma conversa existente, passe `conversationId` no `ChatRequest`.

## Embeddings e rerank

```swift
let e = try await luma.embeddings(["olá", "mundo"])
let vetores = e.vectors            // [[Double]], na ordem de entrada

let r = try await luma.rerank(query: "reembolso", documents: ["Frete em 3 dias.", "Reembolso em 30 dias."])
// r.results: index + relevanceScore, do mais ao menos relevante
```

## Transcrição de áudio

```swift
let t = try await luma.transcribe(audio: try Data(contentsOf: url), filename: "nota.m4a", language: "pt")
print(t.text)

let remoto = try await luma.transcribe(audioUrl: "https://exemplo.com/reuniao.mp3")
```

Cobrado por segundo de áudio. Limite de 100 MB por arquivo.

## Imagens e vídeos

```swift
let img = try await luma.generateImage(ImageOptions(prompt: "um gato astronauta", size: .landscape))
print(img.url ?? "")

let v = try await luma.createVideo(prompt: "ondas no mar ao amanhecer")
let pronto = try await luma.waitForVideo(id: v.id)   // erro se falhar ou passar de 10 min
print(pronto.url ?? "")
```

## Erros

Falhas viram `LumaSdkError`, com `message` e `status` (código HTTP).

## Modelos

| Modelo | Identificador | Bom para |
|--------|--------------|----------|
| Rápido | `.fast` | Respostas rápidas, chat |
| Pensante | `.thinking` | Raciocínio, análise |
| Profundo | `.deep` | Tarefas longas e complexas |

> Migrando da 1.x: saíram `sendAndCollect`, `stream(jobId:)`, `status`, `cancelJob`,
> `siloToken`, `conversations` e `messages` (eram do `/chat` do app). O init agora recebe
> `getToken` que lança erro e devolve `String`, e imagem/vídeo/embeddings usam a `/v1`.
