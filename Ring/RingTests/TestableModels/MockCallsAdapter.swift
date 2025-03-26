import Foundation
@testable import Ring
class MockCallsAdapter: CallsAdapter {
    // MARK: - Call Details Method

    var callDetailsCallCount = 0
    var callDetailsCallId: String?
    var callDetailsAccountId: String?
    var callDetailsReturnValue: [String: String]?

    override func callDetails(withCallId callId: String, accountId: String) -> [String: String]? {
        callDetailsCallCount += 1
        callDetailsCallId = callId
        callDetailsAccountId = accountId
        return callDetailsReturnValue
    }

    var currentMediaListCallCount = 0
    var currentMediaListCallId: String?
    var currentMediaListAccountId: String?
    var currentMediaListReturnValue: [[String: String]]?

    override func currentMediaList(withCallId callId: String, accountId: String) -> [[String: String]]? {
            currentMediaListCallCount += 1
            currentMediaListCallId = callId
            currentMediaListAccountId = accountId
            return currentMediaListReturnValue
        }

    var answerMediaChangeRequestCallCount = 0
    var answerMediaChangeRequestCallId: String?
    var answerMediaChangeRequestAccountId: String?
    var answerMediaChangeRequestMedia: [[String: String]] = []

    func answerMediaChangeResquest(_ callId: String, accountId: String, withMedia media: [[String: String]]) {
        answerMediaChangeRequestCallCount += 1
        answerMediaChangeRequestCallId = callId
        answerMediaChangeRequestAccountId = accountId
        answerMediaChangeRequestMedia = media
    }
}
