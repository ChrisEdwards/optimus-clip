import Foundation

// MARK: - AWS Bedrock Validator

/// Validates AWS Bedrock credentials by making a test API call.
/// Uses lightweight URLSession with AWS Signature V4 signing (no AWS SDK dependency).
enum BedrockValidator {
    /// Validates AWS credentials using a profile from ~/.aws/credentials.
    static func validateProfile(_ profile: String, region: String, modelId: String) async throws -> String {
        guard !profile.isEmpty else {
            throw BedrockValidationError.invalidProfile
        }

        let credentials = try self.loadCredentialsFromProfile(profile)
        return try await self.testConnection(
            accessKey: credentials.accessKey,
            secretKey: credentials.secretKey,
            region: region,
            modelId: modelId
        )
    }

    /// Validates AWS credentials using explicit access keys.
    static func validateKeys(
        accessKey: String,
        secretKey: String,
        region: String,
        modelId: String
    ) async throws -> String {
        guard accessKey.hasPrefix("AKIA") || accessKey.hasPrefix("ASIA") else {
            throw BedrockValidationError.invalidAccessKeyFormat
        }

        guard !secretKey.isEmpty else {
            throw BedrockValidationError.missingSecretKey
        }

        return try await self.testConnection(
            accessKey: accessKey,
            secretKey: secretKey,
            region: region,
            modelId: modelId
        )
    }

    /// Validates AWS credentials using a bearer token (AWS_BEARER_TOKEN_BEDROCK).
    static func validateBearerToken(_ bearerToken: String, region: String, modelId: String) async throws -> String {
        guard !bearerToken.isEmpty else {
            throw BedrockValidationError.missingBearerToken
        }

        return try await self.testConnectionWithBearerToken(
            bearerToken: bearerToken,
            region: region,
            modelId: modelId
        )
    }

    /// Fetches available foundation models from AWS Bedrock.
    static func listModels(
        accessKey: String,
        secretKey: String,
        region: String
    ) async throws -> [BedrockModel] {
        let host = "bedrock.\(region).amazonaws.com"
        let path = "/foundation-models"

        guard let url = URL(string: "https://\(host)\(path)") else {
            throw BedrockValidationError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let signedRequest = try self.signRequest(
            request,
            accessKey: accessKey,
            secretKey: secretKey,
            region: region
        )

        let (data, response) = try await URLSession.shared.data(for: signedRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw BedrockValidationError.apiError("Failed to list models")
        }

        return try self.parseModelsResponse(data: data)
    }

    /// Fetches available foundation models using bearer token authentication.
    static func listModelsWithBearerToken(
        bearerToken: String,
        region: String
    ) async throws -> [BedrockModel] {
        let host = "bedrock.\(region).amazonaws.com"
        let path = "/foundation-models"

        guard let url = URL(string: "https://\(host)\(path)") else {
            throw BedrockValidationError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw BedrockValidationError.apiError("Failed to list models")
        }

        return try self.parseModelsResponse(data: data)
    }

    /// Fetches available foundation models using AWS profile.
    static func listModelsWithProfile(_ profile: String, region: String) async throws -> [BedrockModel] {
        let credentials = try self.loadCredentialsFromProfile(profile)
        return try await self.listModels(
            accessKey: credentials.accessKey,
            secretKey: credentials.secretKey,
            region: region
        )
    }

    private static func testConnection(
        accessKey: String,
        secretKey: String,
        region: String,
        modelId: String
    ) async throws -> String {
        let profileId = InferenceProfileHelper.profileId(for: modelId, region: region)
        let encodedModelId = profileId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? profileId
        let host = "bedrock-runtime.\(region).amazonaws.com"
        let path = "/model/\(encodedModelId)/invoke"

        guard let url = URL(string: "https://\(host)\(path)") else {
            throw BedrockValidationError.invalidEndpoint
        }

        let requestBody = self.buildRequestBody(for: modelId)
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let signedRequest = try self.signRequest(
            request,
            accessKey: accessKey,
            secretKey: secretKey,
            region: region
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: signedRequest)
            return try self.parseResponse(data: data, response: response, region: region)
        } catch let error as BedrockValidationError {
            throw error
        } catch {
            throw self.mapError(error)
        }
    }

    private static func testConnectionWithBearerToken(
        bearerToken: String,
        region: String,
        modelId: String
    ) async throws -> String {
        let profileId = InferenceProfileHelper.profileId(for: modelId, region: region)
        let encodedModelId = profileId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? profileId
        let host = "bedrock-runtime.\(region).amazonaws.com"
        let path = "/model/\(encodedModelId)/invoke"

        guard let url = URL(string: "https://\(host)\(path)") else {
            throw BedrockValidationError.invalidEndpoint
        }

        let requestBody = self.buildRequestBody(for: modelId)
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return try self.parseResponse(data: data, response: response, region: region)
        } catch let error as BedrockValidationError {
            throw error
        } catch {
            throw self.mapError(error)
        }
    }
}

// MARK: - Parsing & Helpers

extension BedrockValidator {
    private static func parseModelsResponse(data: Data) throws -> [BedrockModel] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelSummaries = json["modelSummaries"] as? [[String: Any]] else {
            throw BedrockValidationError.invalidResponse("Invalid models response")
        }

        return modelSummaries.compactMap { summary -> BedrockModel? in
            guard let modelId = summary["modelId"] as? String,
                  let modelName = summary["modelName"] as? String,
                  let providerName = summary["providerName"] as? String else {
                return nil
            }
            return BedrockModel(id: modelId, name: modelName, provider: providerName)
        }.sorted { $0.id < $1.id }
    }

    private static func loadCredentialsFromProfile(_ profile: String) throws -> AWSCredentials {
        let credentialsPath = NSString(string: "~/.aws/credentials").expandingTildeInPath
        let configPath = NSString(string: "~/.aws/config").expandingTildeInPath

        if let credentials = try? self.parseINIFile(path: credentialsPath, profile: profile) {
            return credentials
        }

        let configProfile = profile == "default" ? profile : "profile \(profile)"
        if let credentials = try? self.parseINIFile(path: configPath, profile: configProfile) {
            return credentials
        }

        throw BedrockValidationError.profileNotFound(profile)
    }

    private static func parseINIFile(path: String, profile: String) throws -> AWSCredentials {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw BedrockValidationError.profileNotFound(profile)
        }

        var currentSection = ""
        var accessKey: String?
        var secretKey: String?

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
                currentSection = String(trimmed.dropFirst().dropLast())
            } else if currentSection == profile {
                let parts = trimmed.components(separatedBy: "=").map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2 {
                    switch parts[0] {
                    case "aws_access_key_id":
                        accessKey = parts[1]
                    case "aws_secret_access_key":
                        secretKey = parts[1]
                    default:
                        break
                    }
                }
            }
        }

        guard let key = accessKey, let secret = secretKey else {
            throw BedrockValidationError.profileNotFound(profile)
        }

        return AWSCredentials(accessKey: key, secretKey: secret)
    }

    private static func signRequest(
        _ request: URLRequest,
        accessKey: String,
        secretKey: String,
        region: String,
        service: String = "bedrock"
    ) throws -> URLRequest {
        do {
            return try AWSSigner.signRequest(
                request: request,
                accessKey: accessKey,
                secretKey: secretKey,
                region: region,
                service: service
            )
        } catch AWSSignerError.invalidEndpoint {
            throw BedrockValidationError.invalidEndpoint
        }
    }

    private static func buildRequestBody(for modelId: String) -> [String: Any] {
        let provider = ModelRequestFormat.detect(from: modelId)
        return provider.requestBody
    }

    private static func parseResponse(data: Data, response: URLResponse, region: String) throws -> String {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BedrockValidationError.unexpectedResponse
        }

        let errorMessage = self.extractErrorMessage(from: data)
        let statusCode = httpResponse.statusCode

        if statusCode == 200 {
            return "Connected to AWS Bedrock (\(region))"
        }

        throw self.classifyError(statusCode: statusCode, errorMessage: errorMessage)
    }

    private static func classifyError(statusCode: Int, errorMessage: String?) -> BedrockValidationError {
        switch statusCode {
        case 400:
            self.classify400Error(errorMessage)
        case 401, 403:
            self.classify403Error(errorMessage)
        case 404:
            .modelNotAvailable
        case 429:
            .rateLimited
        case 500 ... 599:
            .serverError(errorMessage ?? "HTTP \(statusCode)")
        default:
            .apiError(errorMessage ?? "HTTP \(statusCode)")
        }
    }

    private static func classify400Error(_ errorMessage: String?) -> BedrockValidationError {
        guard let msg = errorMessage else { return .modelNotAvailable }
        if msg.contains("not found") || msg.contains("not available") {
            return .modelNotAvailable
        }
        return .apiError(msg)
    }

    private static func classify403Error(_ errorMessage: String?) -> BedrockValidationError {
        guard let msg = errorMessage else { return .invalidCredentials }
        if msg.contains("not authorized") || msg.contains("access") || msg.contains("AccessDenied") {
            return .modelAccessNotEnabled
        }
        return .invalidCredentials
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let message = json["message"] as? String {
            return message
        }
        if let error = json["error"] as? String {
            return error
        }
        if let errorObj = json["error"] as? [String: Any], let message = errorObj["message"] as? String {
            return message
        }
        return nil
    }

    private static func mapError(_ error: Error) -> BedrockValidationError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .networkConnectionLost:
                return .networkError
            case .timedOut:
                return .timeout
            default:
                return .networkError
            }
        }
        return .apiError(error.localizedDescription)
    }
}
