import Foundation
import Testing
@testable import OptimusClip

@Suite("UpdaterWrapper Team ID Validation")
struct UpdaterWrapperTests {
    @Test("Rejects placeholder or missing team IDs")
    func rejectsPlaceholders() {
        let placeholders: [String?] = [
            nil,
            "",
            "   ",
            "YOUR_TEAM_ID",
            "$(DEVELOPMENT_TEAM)",
            "$(TEAM_ID)",
            "change_me",
            "CHANGE_ME"
        ]

        for value in placeholders {
            let normalized = UpdaterWrapper.normalizedTeamID(value)
            #expect(normalized == nil, "Expected \(value ?? "nil") to be rejected")
        }
    }

    @Test("Returns trimmed team ID when valid")
    func returnsValidTeamID() {
        let normalized = UpdaterWrapper.normalizedTeamID("  ABC1234TEAM  ")
        #expect(normalized == "ABC1234TEAM")
    }
}
