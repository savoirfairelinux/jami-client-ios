@objc protocol AdapterDelegate {
    func dataTransferEvent(withFileId transferId: String, withEventCode eventCode: Int, accountId: String, conversationId: String, interactionId: String)
    func newInteraction(conversationId: String, accountId: String, message: SwarmMessageWrap)
    func messageStatusChanged(_ status: MessageStatus, for messageId: String, from accountId: String, to jamiId: String, in conversationId: String)

}
