import Foundation

extension TransformationError: Equatable {
    public static func == (lhs: TransformationError, rhs: TransformationError) -> Bool {
        switch (lhs, rhs) {
        case (.emptyInput, .emptyInput):
            true
        case let (.timeout(a), .timeout(b)):
            a == b
        case let (.networkError(a), .networkError(b)):
            a == b
        case (.authenticationError, .authenticationError):
            true
        case let (.processingError(a), .processingError(b)):
            a == b
        case let (.rateLimited(a), .rateLimited(b)):
            a == b
        case let (.contentTooLarge(bytesA, limitA), .contentTooLarge(bytesB, limitB)):
            bytesA == bytesB && limitA == limitB
        default:
            false
        }
    }
}
