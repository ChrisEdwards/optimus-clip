// swiftlint:disable file_length
import CommonCrypto
import Foundation

// MARK: - AWS Bedrock Validator

/// Validates AWS Bedrock credentials by making a test API call.
/// Uses lightweight URLSession with AWS Signature V4 signing (no AWS SDK dependency).
enum BedrockValidator {
    /// Validates AWS credentials using a profile from ~/.aws/credentials.
    /// - Parameters:
    ///   - profile: The AWS profile name to use.
    ///   - region: The AWS region (e.g., "us-east-1").
    ///   - modelId: The model ID to use for validation.
    /// - Returns: A success message describing the validated credentials.
    /// - Throws: An error if validation fails.
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
    /// - Parameters:
    ///   - accessKey: The AWS access key ID.
    ///   - secretKey: The AWS secret access key.
    ///   - region: The AWS region (e.g., "us-east-1").
    ///   - modelId: The model ID to use for validation.
    /// - Returns: A success message describing the validated credentials.
    /// - Throws: An error if validation fails.
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
    /// - Parameters:
    ///   - bearerToken: The AWS bearer token.
    ///   - region: The AWS region (e.g., "us-east-1").
    ///   - modelId: The model ID to use for validation.
    /// - Returns: A success message describing the validated credentials.
    /// - Throws: An error if validation fails.
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
    /// - Parameters:
    ///   - accessKey: The AWS access key ID.
    ///   - secretKey: The AWS secret access key.
    ///   - region: The AWS region.
    /// - Returns: Array of model IDs available in the region.
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

        let signedRequest = try AWSSigner.signRequest(
            request: request,
            accessKey: accessKey,
            secretKey: secretKey,
            region: region,
            service: "bedrock"
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

    // MARK: - Profile Parsing

    private static func loadCredentialsFromProfile(_ profile: String) throws -> AWSCredentials {
        let credentialsPath = NSString(string: "~/.aws/credentials").expandingTildeInPath
        let configPath = NSString(string: "~/.aws/config").expandingTildeInPath

        // Try credentials file first
        if let credentials = try? self.parseINIFile(path: credentialsPath, profile: profile) {
            return credentials
        }

        // Try config file (profile prefix for non-default profiles)
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

    // MARK: - API Test

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

        // Sign request with AWS Signature V4
        let signedRequest = try AWSSigner.signRequest(
            request: request,
            accessKey: accessKey,
            secretKey: secretKey,
            region: region,
            service: "bedrock"
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

    /// Builds the appropriate request body based on the model provider.
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
        // Try common error message fields
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

// MARK: - AWS Signature V4

private enum AWSSigner {
    static func signRequest(
        request: URLRequest,
        accessKey: String,
        secretKey: String,
        region: String,
        service: String
    ) throws -> URLRequest {
        var signedRequest = request

        guard let url = request.url, let host = url.host else {
            throw BedrockValidationError.invalidEndpoint
        }

        let now = Date()
        let amzDate = self.amzDateString(from: now)
        let dateStamp = self.dateStampString(from: now)

        signedRequest.setValue(host, forHTTPHeaderField: "Host")
        signedRequest.setValue(amzDate, forHTTPHeaderField: "X-Amz-Date")

        let bodyHash = self.sha256Hash(data: request.httpBody ?? Data())
        let canonicalRequest = self.buildCanonicalRequest(
            request: request,
            url: url,
            host: host,
            amzDate: amzDate,
            bodyHash: bodyHash
        )
        let stringToSign = self.buildStringToSign(
            amzDate: amzDate,
            dateStamp: dateStamp,
            region: region,
            service: service,
            canonicalRequest: canonicalRequest
        )

        let signature = self.calculateSignature(
            secretKey: secretKey,
            dateStamp: dateStamp,
            region: region,
            service: service,
            stringToSign: stringToSign
        )
        let authorization = self.buildAuthorizationHeader(
            accessKey: accessKey,
            dateStamp: dateStamp,
            region: region,
            service: service,
            signature: signature
        )
        signedRequest.setValue(authorization, forHTTPHeaderField: "Authorization")

        return signedRequest
    }

    private static func buildCanonicalRequest(
        request: URLRequest,
        url: URL,
        host: String,
        amzDate: String,
        bodyHash: String
    ) -> String {
        let canonicalHeaders = "host:\(host)\nx-amz-date:\(amzDate)\n"
        return [
            request.httpMethod ?? "POST",
            url.path,
            url.query ?? "",
            canonicalHeaders,
            "host;x-amz-date",
            bodyHash
        ].joined(separator: "\n")
    }

    private static func buildStringToSign(
        amzDate: String,
        dateStamp: String,
        region: String,
        service: String,
        canonicalRequest: String
    ) -> String {
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        return [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            self.sha256Hash(string: canonicalRequest)
        ].joined(separator: "\n")
    }

    private static func calculateSignature(
        secretKey: String,
        dateStamp: String,
        region: String,
        service: String,
        stringToSign: String
    ) -> String {
        let signingKey = self.getSignatureKey(key: secretKey, dateStamp: dateStamp, region: region, service: service)
        return self.hmacSHA256(key: signingKey, data: Data(stringToSign.utf8)).hexString
    }

    private static func buildAuthorizationHeader(
        accessKey: String,
        dateStamp: String,
        region: String,
        service: String,
        signature: String
    ) -> String {
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        return "AWS4-HMAC-SHA256 Credential=\(accessKey)/\(credentialScope), " +
            "SignedHeaders=host;x-amz-date, Signature=\(signature)"
    }

    private static func amzDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    private static func dateStampString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    private static func sha256Hash(string: String) -> String {
        self.sha256Hash(data: Data(string.utf8))
    }

    private static func sha256Hash(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private static func hmacSHA256(key: Data, data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        key.withUnsafeBytes { keyPtr in
            data.withUnsafeBytes { dataPtr in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA256),
                    keyPtr.baseAddress,
                    key.count,
                    dataPtr.baseAddress,
                    data.count,
                    &hash
                )
            }
        }
        return Data(hash)
    }

    private static func getSignatureKey(key: String, dateStamp: String, region: String, service: String) -> Data {
        let kDate = self.hmacSHA256(key: Data("AWS4\(key)".utf8), data: Data(dateStamp.utf8))
        let kRegion = self.hmacSHA256(key: kDate, data: Data(region.utf8))
        let kService = self.hmacSHA256(key: kRegion, data: Data(service.utf8))
        let kSigning = self.hmacSHA256(key: kService, data: Data("aws4_request".utf8))
        return kSigning
    }
}

// MARK: - Model Request Formats

/// Handles different request body formats for various Bedrock model providers.
private enum ModelRequestFormat {
    case anthropic
    case amazonTitan
    case meta
    case mistral
    case cohere
    case ai21
    case unknown

    /// Detects the provider from a model ID.
    static func detect(from modelId: String) -> ModelRequestFormat {
        let lowercased = modelId.lowercased()
        if lowercased.contains("anthropic") || lowercased.contains("claude") {
            return .anthropic
        } else if lowercased.contains("amazon") || lowercased.contains("titan") {
            return .amazonTitan
        } else if lowercased.contains("meta") || lowercased.contains("llama") {
            return .meta
        } else if lowercased.contains("mistral") {
            return .mistral
        } else if lowercased.contains("cohere") {
            return .cohere
        } else if lowercased.contains("ai21") || lowercased.contains("jamba") || lowercased.contains("jurassic") {
            return .ai21
        }
        return .unknown
    }

    /// Returns the appropriate request body for this provider.
    var requestBody: [String: Any] {
        switch self {
        case .anthropic:
            [
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 10,
                "messages": [["role": "user", "content": "Hi"]]
            ]
        case .amazonTitan:
            [
                "inputText": "Hi",
                "textGenerationConfig": [
                    "maxTokenCount": 10,
                    "temperature": 0.0
                ]
            ]
        case .meta:
            [
                "prompt": "Hi",
                "max_gen_len": 10,
                "temperature": 0.0
            ]
        case .mistral:
            [
                "prompt": "<s>[INST] Hi [/INST]",
                "max_tokens": 10,
                "temperature": 0.0
            ]
        case .cohere:
            [
                "message": "Hi",
                "max_tokens": 10,
                "temperature": 0.0
            ]
        case .ai21:
            [
                "messages": [["role": "user", "content": "Hi"]],
                "max_tokens": 10,
                "temperature": 0.0
            ]
        case .unknown:
            // Default to Anthropic format as it's most common on Bedrock
            [
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 10,
                "messages": [["role": "user", "content": "Hi"]]
            ]
        }
    }
}

// MARK: - Inference Profile Helper

/// Converts model IDs to cross-region inference profile format.
/// Newer AWS Bedrock models require inference profiles like `us.anthropic.claude-3-5-haiku-20241022-v1:0`.
private enum InferenceProfileHelper {
    /// Converts a model ID to cross-region inference profile format if needed.
    static func profileId(for modelId: String, region: String) -> String {
        // If already has a region prefix (us., eu., apac.), return as-is
        if modelId.hasPrefix("us.") || modelId.hasPrefix("eu.") || modelId.hasPrefix("apac.") {
            return modelId
        }
        // If it's an ARN, return as-is
        if modelId.hasPrefix("arn:") {
            return modelId
        }
        // Add region prefix for cross-region inference profile
        let regionPrefix = self.regionPrefix(for: region)
        return "\(regionPrefix)\(modelId)"
    }

    private static func regionPrefix(for region: String) -> String {
        if region.hasPrefix("us-") {
            return "us."
        } else if region.hasPrefix("eu-") {
            return "eu."
        } else if region.hasPrefix("ap-") {
            return "apac."
        }
        // Default to us for other regions
        return "us."
    }
}

// MARK: - Supporting Types

/// Represents an AWS Bedrock foundation model.
struct BedrockModel: Identifiable, Hashable {
    let id: String
    let name: String
    let provider: String

    var displayName: String {
        "\(self.provider): \(self.name)"
    }
}

private struct AWSCredentials {
    let accessKey: String
    let secretKey: String
}

extension Data {
    fileprivate var hexString: String {
        self.map { String(format: "%02x", $0) }.joined()
    }
}

/// Errors that can occur during AWS Bedrock credential validation.
enum BedrockValidationError: LocalizedError {
    case invalidProfile
    case profileNotFound(String)
    case invalidAccessKeyFormat
    case missingSecretKey
    case missingBearerToken
    case invalidCredentials
    case modelAccessNotEnabled
    case modelNotAvailable
    case rateLimited
    case networkError
    case timeout
    case invalidEndpoint
    case serverError(String)
    case apiError(String)
    case invalidResponse(String)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .invalidProfile:
            "Profile name is required"
        case let .profileNotFound(profile):
            "AWS profile '\(profile)' not found. Check ~/.aws/credentials"
        case .invalidAccessKeyFormat:
            "Invalid access key format (should start with AKIA or ASIA)"
        case .missingSecretKey:
            "Secret access key is required"
        case .missingBearerToken:
            "Bearer token is required"
        case .invalidCredentials:
            "Invalid AWS credentials. Check your access key and secret key"
        case .modelAccessNotEnabled:
            "Model access not enabled. Enable in AWS Bedrock Console"
        case .modelNotAvailable:
            "Model not available in selected region. Try us-east-1"
        case .rateLimited:
            "Rate limited. Please wait a moment and try again"
        case .networkError:
            "Network error. Check your internet connection"
        case .timeout:
            "Connection timed out. Check region and network"
        case .invalidEndpoint:
            "Invalid AWS endpoint configuration"
        case let .serverError(message):
            "AWS Bedrock server error: \(message)"
        case let .apiError(message):
            "API error: \(message)"
        case let .invalidResponse(message):
            "Invalid response: \(message)"
        case .unexpectedResponse:
            "Unexpected response from AWS Bedrock"
        }
    }
}
