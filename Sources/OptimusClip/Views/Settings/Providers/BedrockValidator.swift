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
    /// - Returns: A success message describing the validated credentials.
    /// - Throws: An error if validation fails.
    static func validateProfile(_ profile: String, region: String) async throws -> String {
        guard !profile.isEmpty else {
            throw BedrockValidationError.invalidProfile
        }

        let credentials = try self.loadCredentialsFromProfile(profile)
        return try await self.testConnection(
            accessKey: credentials.accessKey,
            secretKey: credentials.secretKey,
            region: region
        )
    }

    /// Validates AWS credentials using explicit access keys.
    /// - Parameters:
    ///   - accessKey: The AWS access key ID.
    ///   - secretKey: The AWS secret access key.
    ///   - region: The AWS region (e.g., "us-east-1").
    /// - Returns: A success message describing the validated credentials.
    /// - Throws: An error if validation fails.
    static func validateKeys(
        accessKey: String,
        secretKey: String,
        region: String
    ) async throws -> String {
        guard accessKey.hasPrefix("AKIA") || accessKey.hasPrefix("ASIA") else {
            throw BedrockValidationError.invalidAccessKeyFormat
        }

        guard !secretKey.isEmpty else {
            throw BedrockValidationError.missingSecretKey
        }

        return try await self.testConnection(accessKey: accessKey, secretKey: secretKey, region: region)
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
        region: String
    ) async throws -> String {
        // Use Claude 3 Haiku for validation (fast, cheap, widely available)
        let modelId = "anthropic.claude-3-haiku-20240307-v1:0"
        let host = "bedrock-runtime.\(region).amazonaws.com"
        let path = "/model/\(modelId)/invoke"

        guard let url = URL(string: "https://\(host)\(path)") else {
            throw BedrockValidationError.invalidEndpoint
        }

        // Build minimal request body for Claude model
        let requestBody: [String: Any] = [
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 10,
            "messages": [
                ["role": "user", "content": "Hi"]
            ]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        // Sign request with AWS Signature V4
        let signedRequest = try self.signRequest(
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

    private static func parseResponse(data: Data, response: URLResponse, region: String) throws -> String {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BedrockValidationError.unexpectedResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return "Connected to AWS Bedrock (\(region))"
        case 400:
            throw BedrockValidationError.modelNotAvailable
        case 401, 403:
            // Check if it's a model access issue vs credentials issue
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                if message.contains("not authorized") || message.contains("access") {
                    throw BedrockValidationError.modelAccessNotEnabled
                }
            }
            throw BedrockValidationError.invalidCredentials
        case 404:
            throw BedrockValidationError.modelNotAvailable
        case 429:
            throw BedrockValidationError.rateLimited
        case 500 ... 599:
            throw BedrockValidationError.serverError("HTTP \(httpResponse.statusCode)")
        default:
            throw BedrockValidationError.apiError("HTTP \(httpResponse.statusCode)")
        }
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

    // MARK: - AWS Signature V4

    private static func signRequest(
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

// MARK: - Supporting Types

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
    case invalidCredentials
    case modelAccessNotEnabled
    case modelNotAvailable
    case rateLimited
    case networkError
    case timeout
    case invalidEndpoint
    case serverError(String)
    case apiError(String)
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
        case .unexpectedResponse:
            "Unexpected response from AWS Bedrock"
        }
    }
}
