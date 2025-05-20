#import <Foundation/Foundation.h>

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
