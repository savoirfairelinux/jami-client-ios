@objc protocol AdapterDelegate {
    func dataTransferEvent(withFileId transferId: String, withEventCode eventCode: Int, accountId: String, conversationId: String, interactionId: String)
    func newInteraction(conversationId: String, accountId: String, message: SwarmMessageWrap)

}
