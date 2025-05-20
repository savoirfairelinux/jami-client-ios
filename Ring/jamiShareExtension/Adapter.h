#import <Foundation/Foundation.h>

typedef NS_ENUM(int, MessageStatus)  {
    MessageStatusUnknown = 0,
    MessageStatusSending,
    MessageStatusSent,
    MessageStatusDisplayed,
    MessageStatusFailure,
    MessageStatusCanceled
};

@interface SwarmMessageWrap : NSObject

@property (nonatomic, strong) NSString* id;
@property (nonatomic, strong) NSString* type;
@property (nonatomic, strong) NSString* linearizedParent;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *>* body;
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, NSString *> *>* reactions;
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, NSString *> *>* editions;
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber* >* status;

@end


@protocol AdapterDelegate;

@interface Adapter: NSObject

@property (class, nonatomic, weak) id <AdapterDelegate> delegate;

// Delegate
+ (id<AdapterDelegate>)delegate;
+ (void)setDelegate:(id<AdapterDelegate>)delegate;

// Daemon
- (BOOL)initDaemon;
- (BOOL)startDaemon;
- (void)fini;

// Account
- (NSArray *)getAccountList;
- (void)setAccountActive:(NSString *)accountID
                  active:(bool)active;

// Conversation
- (NSArray*)getSwarmConversationsForAccount:(NSString*) accountId;
- (void)sendSwarmMessage:(NSString*)accountId conversationId:(NSString*)conversationId message:(NSString*)message parentId:(NSString*)parentId flag:(int32_t)flag;
- (void)sendSwarmFileWithName:(NSString*)displayName
                    accountId:(NSString*)accountId
               conversationId:(NSString*)conversationId
                 withFilePath:(NSString*)filePath
                       parent:(NSString*)parent;

@end
