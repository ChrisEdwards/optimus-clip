import CommonCrypto
import Foundation

enum AWSSignerError: Error {
    case invalidEndpoint
}

/// Minimal AWS Signature V4 signer used for Bedrock requests.
enum AWSSigner {
    private struct SigningContext {
        let url: URL
        let host: String
        let amzDate: String
        let dateStamp: String
        let bodyHash: String
        let region: String
        let service: String
        let signedHeaders: String = "host;x-amz-content-sha256;x-amz-date"
    }

    static func signRequest(
        request: URLRequest,
        accessKey: String,
        secretKey: String,
        region: String,
        service: String
    ) throws -> URLRequest {
        let context = try self.makeSigningContext(for: request, region: region, service: service)
        var signedRequest = self.applyDefaultHeaders(context, to: request)

        let canonicalRequest = self.buildCanonicalRequest(request: signedRequest, context: context)
        let stringToSign = self.buildStringToSign(context: context, canonicalRequest: canonicalRequest)

        let signature = self.calculateSignature(
            secretKey: secretKey,
            dateStamp: context.dateStamp,
            region: context.region,
            service: context.service,
            stringToSign: stringToSign
        )
        let authorization = self.buildAuthorizationHeader(
            accessKey: accessKey,
            signature: signature,
            context: context
        )
        signedRequest.setValue(authorization, forHTTPHeaderField: "Authorization")

        return signedRequest
    }

    private static func makeSigningContext(
        for request: URLRequest,
        region: String,
        service: String,
        now: Date = Date()
    ) throws -> SigningContext {
        guard let url = request.url, let host = url.host else {
            throw AWSSignerError.invalidEndpoint
        }

        return SigningContext(
            url: url,
            host: host,
            amzDate: self.amzDateString(from: now),
            dateStamp: self.dateStampString(from: now),
            bodyHash: self.sha256Hash(data: request.httpBody ?? Data()),
            region: region,
            service: service
        )
    }

    private static func applyDefaultHeaders(_ context: SigningContext, to request: URLRequest) -> URLRequest {
        var signedRequest = request
        signedRequest.setValue(context.host, forHTTPHeaderField: "Host")
        signedRequest.setValue(context.amzDate, forHTTPHeaderField: "X-Amz-Date")
        signedRequest.setValue(context.bodyHash, forHTTPHeaderField: "X-Amz-Content-Sha256")
        return signedRequest
    }

    private static func buildCanonicalRequest(
        request: URLRequest,
        context: SigningContext
    ) -> String {
        let canonicalHeaders = [
            "host:\(context.host)",
            "x-amz-content-sha256:\(context.bodyHash)",
            "x-amz-date:\(context.amzDate)"
        ].joined(separator: "\n") + "\n"

        return [
            request.httpMethod ?? "POST",
            context.url.path,
            context.url.query ?? "",
            canonicalHeaders,
            context.signedHeaders,
            context.bodyHash
        ].joined(separator: "\n")
    }

    private static func buildStringToSign(
        context: SigningContext,
        canonicalRequest: String
    ) -> String {
        let credentialScope = "\(context.dateStamp)/\(context.region)/\(context.service)/aws4_request"
        return [
            "AWS4-HMAC-SHA256",
            context.amzDate,
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
        signature: String,
        context: SigningContext
    ) -> String {
        let credentialScope = "\(context.dateStamp)/\(context.region)/\(context.service)/aws4_request"
        return "AWS4-HMAC-SHA256 Credential=\(accessKey)/\(credentialScope), " +
            "SignedHeaders=\(context.signedHeaders), Signature=\(signature)"
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

extension Data {
    fileprivate var hexString: String {
        self.map { String(format: "%02x", $0) }.joined()
    }
}
