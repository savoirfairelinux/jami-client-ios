import Foundation
import ObjectiveC
@testable import Ring

// Final approach - create our own implementation that manually tracks properties
//class MockCallsAdapter: CallsAdapter {
//    // MARK: - Call Details Method
//
//    var callDetailsCallCount = 0
//    var callDetailsCallId: String?
//    var callDetailsAccountId: String?
//    var callDetailsReturnValue: [String: String]?
//
//    override func callDetails(withCallId callId: String, accountId: String) -> [String: String]? {
//        callDetailsCallCount += 1
//        callDetailsCallId = callId
//        callDetailsAccountId = accountId
//        return callDetailsReturnValue
//    }
//
//    var currentMediaListCallCount = 0
//    var currentMediaListCallId: String?
//    var currentMediaListAccountId: String?
//    var currentMediaListReturnValue: [[String: String]]?
//
//    override func currentMediaList(withCallId callId: String, accountId: String) -> [[String: String]]? {
//        currentMediaListCallCount += 1
//        currentMediaListCallId = callId
//        currentMediaListAccountId = accountId
//        return currentMediaListReturnValue
//    }
//
//    var answerMediaChangeResquestCallCount = 0
//    var answerMediaChangeResquestCallId: String?
//    var answerMediaChangeResquestAccountId: String?
//    var answerMediaChangeResquestMedia: [[String: String]] = []
//    
//    // Use a direct selector-based override with explicit Objective-C name
//    @objc(answerMediaChangeResquest:accountId:withMedia:)
//    override func answerMediaChangeResquest(_ callId: String, accountId: String, withMedia media: [[String: String]]) {
//        NSLog("ℹ️ MockCallsAdapter: answerMediaChangeResquest called")
//        print("📞 Method parameters: callId=\(callId), accountId=\(accountId), media.count=\(media.count)")
//        answerMediaChangeResquestCallCount += 1
//        answerMediaChangeResquestCallId = callId
//        answerMediaChangeResquestAccountId = accountId
//        answerMediaChangeResquestMedia = media
//        
//        // Skip calling super implementation
//    }
//    
//    // Make sure we track incoming messages for this selector
//    override func responds(to aSelector: Selector!) -> Bool {
//        if aSelector.description.contains("answerMediaChangeResquest") {
//            NSLog("ℹ️ Check if responds to: \(aSelector.description)")
//            return true
//        }
//        return super.responds(to: aSelector)
//    }
//}
