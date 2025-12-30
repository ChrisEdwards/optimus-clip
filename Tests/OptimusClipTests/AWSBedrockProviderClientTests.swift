import Foundation
import OptimusClipCore
import Testing
@testable import OptimusClip

@Suite("AWS Bedrock Provider Client")
struct AWSBedrockProviderClientTests {
    @Test("SigV4 credentials are treated as configured")
    func sigV4CredentialsAreConfigured() {
        let client = AWSBedrockProviderClient(
            accessKey: "AKIAEXAMPLEKEY",
            secretKey: "exampleSecretKeyValue",
            region: "us-east-1"
        )

        #expect(client.isConfigured())
    }

    @Test("Signs requests with AWS4 signature headers")
    func signsRequestsWithSigV4() throws {
        let client = AWSBedrockProviderClient(
            accessKey: "AKIAEXAMPLEKEY",
            secretKey: "exampleSecretKeyValue",
            region: "us-east-1"
        )

        let request = LLMRequest(
            provider: .awsBedrock,
            model: "anthropic.claude-3-haiku:1",
            text: "Hello",
            systemPrompt: "You are a test",
            temperature: 0.1,
            timeout: 5
        )

        let signedRequest = try client.makeSignedRequest(request)
        let authorization = signedRequest.value(forHTTPHeaderField: "Authorization")

        #expect(authorization?.hasPrefix("AWS4-HMAC-SHA256") == true)
        #expect(signedRequest.value(forHTTPHeaderField: "X-Amz-Date")?.isEmpty == false)
        #expect(signedRequest.value(forHTTPHeaderField: "X-Amz-Content-Sha256")?.isEmpty == false)
        #expect(signedRequest.value(forHTTPHeaderField: "Host") == "bedrock-runtime.us-east-1.amazonaws.com")
    }

    @Test("Bearer token authentication sets bearer header")
    func bearerTokenUsesAuthorizationHeader() throws {
        let client = AWSBedrockProviderClient(
            bearerToken: "BEARER_TOKEN",
            region: "us-west-2"
        )

        let request = LLMRequest(
            provider: .awsBedrock,
            model: "anthropic.claude-3-haiku:1",
            text: "Hello",
            systemPrompt: "You are a test",
            temperature: 0.1,
            timeout: 5
        )

        let signedRequest = try client.makeSignedRequest(request)

        #expect(signedRequest.value(forHTTPHeaderField: "Authorization") == "Bearer BEARER_TOKEN")
        #expect(signedRequest.value(forHTTPHeaderField: "X-Amz-Date") == nil)
        #expect(signedRequest.value(forHTTPHeaderField: "X-Amz-Content-Sha256") == nil)
    }
}
