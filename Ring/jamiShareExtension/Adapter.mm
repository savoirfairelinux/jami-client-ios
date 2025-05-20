// UIKit imported to support the use of UIViewController
#import <UIKit/UIKit.h>

// Share extension dependencies imports
#import "jamiShareExtension-Swift.h"
#import "Adapter.h"
#import "Utils.h"

// libjami imports
#import "jami/jami.h"
#import "jami/configurationmanager_interface.h"
#import "jami/conversation_interface.h"
#import "jami/datatransfer_interface.h"

@implementation Adapter

static id<AdapterDelegate> _delegate;

using namespace libjami;

// Callback constnts
std::map<std::string, std::shared_ptr<CallbackWrapperBase>> confHandlers;
std::map<std::string, std::pair<std::string, std::string>> cachedNames;
std::map<std::string, std::string> nameServers;

// Callbacks registration
- (void)registerSignals
{
    confHandlers.insert(exportable_callback<ConfigurationSignal::GetAppDataPath>(
        [](const std::string& name, std::vector<std::string>* ret) {
            if (name == "cache") {
                auto path = [Constants cachesPath];
                ret->push_back(std::string([path.path UTF8String]));
            } else {
                auto path = [Constants documentsPath];
                ret->push_back(std::string([path.path UTF8String]));
            }
        })); // This closes the exportable_callback call correctly.

    registerSignalHandlers(confHandlers);
}

#pragma mark - AdapterDelegate

+ (id<AdapterDelegate>)delegate {
    return _delegate;
}

+ (void)setDelegate:(id<AdapterDelegate>)delegate {
    _delegate = delegate;
}

// Adapter initialization
- (id)init {
    self = [super init];
    [self registerDataTransferHandlers];
    return self;
}

// Daemon

- (BOOL)initDaemon {
    if (![[NSThread currentThread] isMainThread]) {
        __block bool success;
        dispatch_sync(dispatch_get_main_queue(), ^{
            success = [self initDaemonInternal];
        });
        return success;
    }
    else {
        return [self initDaemonInternal];
    }
}

- (BOOL) initDaemonInternal {
#if DEBUG
    int flag = LIBJAMI_FLAG_DEBUG | LIBJAMI_FLAG_CONSOLE_LOG | LIBJAMI_FLAG_SYSLOG | LIBJAMI_FLAG_NO_LOCAL_AUDIO;
#else
    int flag = 0;
#endif
    return init(static_cast<InitFlag>(flag));
}

- (BOOL)startDaemon {
    [self registerSignals];

    if (![[NSThread currentThread] isMainThread]) {
        __block bool success;
        dispatch_sync(dispatch_get_main_queue(), ^{
            success = [self startDaemonInternal];
        });
        return success;
    }
    else {
        return [self startDaemonInternal];
    }
}

- (BOOL)startDaemonInternal {
    return start();
}

- (void)fini {
    if (![[NSThread currentThread] isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            fini();
        });
    }
    else {
        fini();
    }
}

// Account

- (NSArray *)getAccountList {
    auto accountVector = libjami::getAccountList(); // prevent recursion

    NSArray *accountArray = [Utils vectorToArray:accountVector];

    return accountArray;
}

- (void)setAccountActive:(NSString *)accountID
                  active:(bool)active {
    setAccountActive(std::string([accountID UTF8String]), active, true);
    printf("*** SET ACCT ACTIVE CALLED ***");
        
}

// Conversation

- (NSArray*)getSwarmConversationsForAccount:(NSString*) accountId {
    return [Utils vectorToArray: getConversations(std::string([accountId UTF8String]))];
}

- (void)sendSwarmMessage:(NSString*)accountId conversationId:(NSString*)conversationId message:(NSString*)message parentId:(NSString*)parentId flag:(int32_t)flag {
    sendMessage(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([message UTF8String]), std::string([parentId UTF8String]), flag);
}

- (void)sendSwarmFileWithName:(NSString*)displayName
                    accountId:(NSString*)accountId
               conversationId:(NSString*)conversationId
                 withFilePath:(NSString*)filePath
                       parent:(NSString*)parent {
    sendFile(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([filePath UTF8String]), std::string([displayName UTF8String]), std::string([parent UTF8String]));
}

- (void)registerDataTransferHandlers {
    
    
    std::map<std::string, std::shared_ptr<CallbackWrapperBase>> dataTransferHandlers;
    
    dataTransferHandlers
    .insert(exportable_callback<DataTransferSignal::DataTransferEvent>([&](const std::string& account_id,
                                                                           const std::string& conversation_id,
                                                                           const std::string& interaction_id,
                                                                           const std::string& file_id,
                                                                           int eventCode) {
        
        if(Adapter.delegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* conversationId = [NSString stringWithUTF8String:conversation_id.c_str()];
            NSString* fileId = [NSString stringWithUTF8String:file_id.c_str()];
            NSString* interactionId = [NSString stringWithUTF8String:interaction_id.c_str()];
            
            
            [Adapter.delegate dataTransferEventWithFileId:fileId
                                            withEventCode:eventCode
                                                accountId:accountId
                                           conversationId:conversationId
                                           interactionId:interactionId];
        } else {
            NSLog(@"[WARNING] Adapter.delegate is nil");
        }
    }));
    
    registerSignalHandlers(dataTransferHandlers);
    NSLog(@"[DEBUG] registerSignalHandlers called");
}


@end
