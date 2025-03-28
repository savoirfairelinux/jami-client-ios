#import <Foundation/Foundation.h>
#import "CallsAdapter.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Objective-C implementation of a mock calls adapter for testing
 */
@interface ObjCMockCallsAdapter : CallsAdapter

// Call details
@property (nonatomic, assign) NSInteger callDetailsCallCount;
@property (nonatomic, copy, nullable) NSString *callDetailsCallId;
@property (nonatomic, copy, nullable) NSString *callDetailsAccountId;
@property (nonatomic, copy, nullable) NSDictionary<NSString*, NSString*> *callDetailsReturnValue;

// Current media list
@property (nonatomic, assign) NSInteger currentMediaListCallCount;
@property (nonatomic, copy, nullable) NSString *currentMediaListCallId;
@property (nonatomic, copy, nullable) NSString *currentMediaListAccountId;
@property (nonatomic, copy, nullable) NSArray<NSDictionary<NSString*, NSString*>*> *currentMediaListReturnValue;

// Answer media change request
@property (nonatomic, assign) NSInteger answerMediaChangeResquestCallCount;
@property (nonatomic, copy, nullable) NSString *answerMediaChangeResquestCallId;
@property (nonatomic, copy, nullable) NSString *answerMediaChangeResquestAccountId;
@property (nonatomic, copy, nullable) NSArray<NSDictionary<NSString*, NSString*>*> *answerMediaChangeResquestMedia;

@end

NS_ASSUME_NONNULL_END 