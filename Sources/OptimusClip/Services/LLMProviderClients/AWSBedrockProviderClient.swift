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
        self.credentials.isConfiguredAndSupported
    }

    public func transform(_ request: LLMRequest) async throws -> LLMResponse {
        guard self.isConfigured() else {
            throw LLMProviderError.notConfigured
        }

        let startTime = Date()
        let urlRequest = try self.makeSignedRequest(request)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch let urlError as URLError {
            throw self.mapURLError(urlError)
        }

        try self.validateResponse(response, data: data)

        let converseResponse = try JSONDecoder().decode(BedrockConverseResponse.self, from: data)
        return self.buildLLMResponse(converseResponse, model: request.model, startTime: startTime)
    }

    // MARK: - Helpers

    func makeSignedRequest(_ request: LLMRequest) throws -> URLRequest {
        let baseRequest = try self.buildRequest(request)
        return try self.applyAuthentication(to: baseRequest)
    }

    private func buildRequest(_ request: LLMRequest) throws -> URLRequest {
        guard let url = self.buildConverseURL(modelId: request.model, region: self.region) else {
            throw LLMProviderError.invalidResponse("Invalid Bedrock URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // URLRequest timeout is a safety net; primary timeout is handled by async withTimeout wrapper
        // in LLMTransformation. Set this 50% longer to ensure async timeout fires first.
        urlRequest.timeoutInterval = request.timeout * 1.5

        let body = BedrockConverseRequest(
            system: [BedrockSystemContent(text: request.systemPrompt)],
            messages: [BedrockMessage(role: "user", content: [BedrockContent(text: request.text)])],
            inferenceConfig: BedrockInferenceConfig(
                temperature: request.temperature,
                maxTokens: 12000
            )
        )
        urlRequest.httpBody = try JSONEncoder().encode(body)
        return urlRequest
    }

    private func buildConverseURL(modelId: String, region: String) -> URL? {
        let host = "bedrock-runtime.\(region).amazonaws.com"
        // Convert to inference profile ID if needed (newer models require us./eu./apac. prefix)
        let profileId = InferenceProfileHelper.profileId(for: modelId, region: region)
        // Model ID must be URL-encoded - colons in model IDs (like "anthropic.claude-3-haiku:0")
        // must be percent-encoded as %3A for AWS URLs
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(":")
        guard let encodedModelId = profileId.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        let path = "/model/\(encodedModelId)/converse"
        return URL(string: "https://\(host)\(path)")
    }

    private func applyAuthentication(to request: URLRequest) throws -> URLRequest {
        switch self.credentials {
        case let .bearer(token):
            var authenticated = request
            authenticated.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            return authenticated
        case let .sigV4(accessKey, secretKey):
            do {
                return try AWSSigner.signRequest(
                    request: request,
                    accessKey: accessKey,
                    secretKey: secretKey,
                    region: self.region,
                    service: "bedrock"
                )
            } catch AWSSignerError.invalidEndpoint {
                throw LLMProviderError.invalidResponse("Invalid AWS Bedrock endpoint")
            }
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
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
            // Try to parse error message from AWS response
            let errorMessage = self.parseErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw LLMProviderError.server(errorMessage)
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        // AWS Bedrock error format: {"message":"..."}
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? String else {
            return nil
        }
        return message
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

    var isConfiguredAndSupported: Bool {
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
