#import "ObjCMockCallsAdapter.h"

@implementation ObjCMockCallsAdapter

- (nullable NSDictionary<NSString *, NSString *> *)callDetailsWithCallId:(NSString *)callId accountId:(NSString *)accountId {
    self.callDetailsCallCount++;
    self.callDetailsCallId = callId;
    self.callDetailsAccountId = accountId;
    return self.callDetailsReturnValue;
}

- (nullable NSArray<NSDictionary<NSString *, NSString *> *> *)currentMediaListWithCallId:(NSString *)callId accountId:(NSString *)accountId {
    self.currentMediaListCallCount++;
    self.currentMediaListCallId = callId;
    self.currentMediaListAccountId = accountId;
    return self.currentMediaListReturnValue;
}

- (void)answerMediaChangeResquest:(NSString *)callId accountId:(NSString *)accountId withMedia:(NSArray *)mediaList {
    NSLog(@"ObjCMockCallsAdapter: answerMediaChangeResquest called with callId: %@, accountId: %@, media count: %lu", 
          callId, accountId, (unsigned long)mediaList.count);
    
    self.answerMediaChangeResquestCallCount++;
    self.answerMediaChangeResquestCallId = callId;
    self.answerMediaChangeResquestAccountId = accountId;
    self.answerMediaChangeResquestMedia = mediaList;
}

@end 