#import <Foundation/Foundation.h>

// MESSAGE STATUS INDICATOR

typedef NS_ENUM(int, MessageStatus)  {
    MessageStatusUnknown = 0,
    MessageStatusSending,
    MessageStatusSent,
    MessageStatusDisplayed,
    MessageStatusFailure,
    MessageStatusCanceled
};

typedef NS_ENUM(UInt32, NSDataTransferEventCode)  {
    invalid = 0,
    created,
    unsupported,
    wait_peer_acceptance,
    wait_host_acceptance,
    ongoing,
    finished,
    closed_by_host,
    closed_by_peer,
    invalid_pathname,
    unjoinable_peer
};

typedef NS_ENUM(UInt32, NSDataTransferError)  {
    success = 0,
    unknown,
    io,
    invalid_argument
};

typedef NS_ENUM(UInt32, NSDataTransferFlags)  {
    direction = 0 // 0: outgoing, 1: incoming
};

@interface NSDataTransferInfo: NSObject
{
@public
    NSString* accountId;
    NSDataTransferEventCode lastEvent;
    UInt32 flags;
    int64_t totalSize;
    int64_t bytesProgress;
    NSString* peer;
    NSString* displayName;
    NSString* path;
    NSString* mimetype;
    NSString* conversationId;
}
@property (strong, nonatomic) NSString* accountId;
@property (nonatomic) NSDataTransferEventCode lastEvent;
@property (nonatomic) UInt32 flags;
@property (nonatomic) int64_t totalSize;
@property (nonatomic) int64_t bytesProgress;
@property (strong, nonatomic) NSString* peer;
@property (strong, nonatomic) NSString* displayName;
@property (strong, nonatomic) NSString* path;
@property (strong, nonatomic) NSString* conversationId;
@property (strong, nonatomic) NSString* mimetype;
@end


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

// MAIN ADAPTER

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

- (NSDataTransferError) dataTransferInfoWithId:(NSString*)fileId
                                          accountId:(NSString*)accountId
                                           withInfo:(NSDataTransferInfo*)info;

@end
