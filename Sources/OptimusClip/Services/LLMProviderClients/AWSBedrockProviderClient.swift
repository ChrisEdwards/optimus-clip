import Foundation
import OptimusClipCore

/// AWS Bedrock provider client for Claude models via Bedrock Converse API.
///
/// Supports bearer token authentication (AWS IAM Identity Center) or
/// standard IAM credentials with SigV4 signing.
public struct AWSBedrockProviderClient: LLMProviderClient, Sendable {
    public let provider: LLMProviderKind = .awsBedrock

    private let credentials: BedrockCredentials
    private let region: String

    public init(accessKey: String, secretKey: String, region: String) {
        self.credentials = .sigV4(accessKey: accessKey, secretKey: secretKey)
        self.region = region
    }

    public init(bearerToken: String, region: String) {
        self.credentials = .bearer(token: bearerToken)
        self.region = region
    }

    public func isConfigured() -> Bool {
        self.credentials.isValid
    }

    public func transform(_ request: LLMRequest) async throws -> LLMResponse {
        guard self.isConfigured() else {
            throw LLMProviderError.notConfigured
        }

        let startTime = Date()
        var urlRequest = try self.buildRequest(request)
        try self.applyAuthentication(to: &urlRequest)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch let urlError as URLError {
            throw self.mapURLError(urlError)
        }

        try self.validateResponse(response)

        let converseResponse = try JSONDecoder().decode(BedrockConverseResponse.self, from: data)
        return self.buildLLMResponse(converseResponse, model: request.model, startTime: startTime)
    }

    // MARK: - Helpers

    private func buildRequest(_ request: LLMRequest) throws -> URLRequest {
        guard let url = self.buildConverseURL(modelId: request.model) else {
            throw LLMProviderError.invalidResponse("Invalid Bedrock URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = request.timeout

        let body = BedrockConverseRequest(
            system: [BedrockSystemContent(text: request.systemPrompt)],
            messages: [BedrockMessage(role: "user", content: [BedrockContent(text: request.text)])],
            inferenceConfig: BedrockInferenceConfig(
                temperature: request.temperature,
                maxTokens: request.maxTokens ?? 4096
            )
        )
        urlRequest.httpBody = try JSONEncoder().encode(body)
        return urlRequest
    }

    private func buildConverseURL(modelId: String) -> URL? {
        let host = "bedrock-runtime.\(self.region).amazonaws.com"
        let path = "/model/\(modelId)/converse"
        return URL(string: "https://\(host)\(path)")
    }

    private func applyAuthentication(to request: inout URLRequest) throws {
        switch self.credentials {
        case let .bearer(token):
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .sigV4:
            // SigV4 signing requires complex HMAC-SHA256 computation that is not yet implemented.
            // Users should use bearer token authentication via AWS IAM Identity Center instead.
            throw LLMProviderError.authenticationError
        }
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMProviderError.invalidResponse("Invalid response type")
        }

        switch httpResponse.statusCode {
        case 200:
            return
        case 401, 403:
            throw LLMProviderError.authenticationError
        case 429:
            throw LLMProviderError.rateLimited(retryAfter: self.parseRetryAfter(httpResponse))
        case 404:
            throw LLMProviderError.modelNotFound
        case 500 ... 599:
            throw LLMProviderError.server("AWS Bedrock server error")
        default:
            throw LLMProviderError.server("HTTP \(httpResponse.statusCode)")
        }
    }

    private func parseRetryAfter(_ response: HTTPURLResponse) -> TimeInterval? {
        guard let retryValue = response.value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }
        return TimeInterval(retryValue)
    }

    private func buildLLMResponse(
        _ response: BedrockConverseResponse,
        model: String,
        startTime: Date
    ) -> LLMResponse {
        let output = response.output.message.content.first?.text ?? ""
        return LLMResponse(
            provider: .awsBedrock,
            model: model,
            output: output,
            duration: Date().timeIntervalSince(startTime)
        )
    }

    private func mapURLError(_ error: URLError) -> LLMProviderError {
        switch error.code {
        case .timedOut:
            .timeout
        case .notConnectedToInternet:
            .network("No internet connection")
        case .networkConnectionLost:
            .network("Connection lost")
        case .cannotFindHost, .cannotConnectToHost:
            .network("Cannot connect to AWS Bedrock")
        case .dnsLookupFailed:
            .network("DNS lookup failed")
        default:
            .network(error.localizedDescription)
        }
    }
}

// MARK: - Internal Types

private enum BedrockCredentials: Sendable {
    case sigV4(accessKey: String, secretKey: String)
    case bearer(token: String)

    var isValid: Bool {
        switch self {
        case let .sigV4(accessKey, secretKey):
            !accessKey.isEmpty && !secretKey.isEmpty
        case let .bearer(token):
            !token.isEmpty
        }
    }
}

// MARK: - Bedrock Converse API Types

private struct BedrockConverseRequest: Encodable {
    let system: [BedrockSystemContent]
    let messages: [BedrockMessage]
    let inferenceConfig: BedrockInferenceConfig
}

private struct BedrockSystemContent: Encodable {
    let text: String
}

private struct BedrockMessage: Encodable {
    let role: String
    let content: [BedrockContent]
}

private struct BedrockContent: Codable {
    let text: String
}

private struct BedrockInferenceConfig: Encodable {
    let temperature: Double
    let maxTokens: Int
}

private struct BedrockConverseResponse: Decodable {
    let output: BedrockOutput
}

private struct BedrockOutput: Decodable {
    let message: BedrockResponseMessage
}

private struct BedrockResponseMessage: Decodable {
    let content: [BedrockContent]
}
