import Foundation

struct OpenAIModelsResponse: Decodable {
    let data: [OpenAIModel]
}

struct OpenAIModel: Decodable {
    let id: String
}

struct OpenRouterModelsResponse: Decodable {
    let data: [OpenRouterModel]
}

struct OpenRouterModel: Decodable {
    let id: String
    let name: String?
    let description: String?
    let contextLength: Int?
    let pricing: Pricing?
    let deprecated: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case contextLength = "context_length"
        case pricing
        case deprecated
    }

    struct Pricing: Decodable {
        let prompt: String?
        let completion: String?
    }
}

struct OllamaTagsResponse: Decodable {
    let models: [OllamaModel]
}

struct OllamaModel: Decodable {
    let name: String
}
