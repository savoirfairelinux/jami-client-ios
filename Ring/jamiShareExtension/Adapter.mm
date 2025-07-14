/*
 *  Copyright (C) 2025-2025 Savoir-faire Linux Inc.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

// Required before importing jamiShareExtension-Swift.h: Swift clas ShareViewController inherit from UIViewController
#import <UIKit/UIKit.h>

#import "jamiShareExtension-Swift.h"
#import "Adapter.h"
#import "Utils.h"

#import "jami/jami.h"
#import "jami/configurationmanager_interface.h"
#import "jami/conversation_interface.h"
#import "jami/datatransfer_interface.h"

@implementation LookupNameResponse
@end

@implementation NSDataTransferInfo
@synthesize accountId, lastEvent, flags, totalSize, bytesProgress, peer, displayName, path, mimetype, conversationId;

- (id) init {
    if (self = [super init]) {
        self->lastEvent = invalid;
        self->flags = 0;
        self->totalSize = 0;
        self->bytesProgress = 0;

    }
    return self;
};

@end

@implementation SwarmMessageWrap

- (instancetype)initWithSwarmMessage:(const libjami::SwarmMessage &)message {
    self = [super init];
    if (self) {
        self.id = @(message.id.c_str());
        self.type = @(message.type.c_str());
        self.linearizedParent = @(message.linearizedParent.c_str());
        self.body = [Utils mapToDictionnary: message.body];
        self.reactions = [Utils vectorOfMapsToArray: message.reactions];
        self.editions = [Utils vectorOfMapsToArray: message.editions];
        self.status = [Utils mapToDictionnaryWithInt: message.status];
    }
    return self;
}

@end

@implementation Adapter

static id<AdapterDelegate> _delegate;

using namespace libjami;

std::map<std::string, std::shared_ptr<CallbackWrapperBase>> confHandlers;

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
        }));

    confHandlers.insert(exportable_callback<ConversationSignal::SwarmMessageReceived>([weakDelegate = Adapter.delegate](const std::string& accountId, const std::string& conversationId, libjami::SwarmMessage message) {
        if (weakDelegate) {
            NSString* convId =  [NSString stringWithUTF8String:conversationId.c_str()];
            NSString* account =  [NSString stringWithUTF8String:accountId.c_str()];
            SwarmMessageWrap *swarmMessage = [[SwarmMessageWrap alloc] initWithSwarmMessage: message];
            [weakDelegate newInteractionWithConversationId: convId accountId: account message: swarmMessage];
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::AccountMessageStatusChanged>([weakDelegate = Adapter.delegate](const std::string& account_id, const std::string& conversation_id, const std::string& peer, const std::string message_id, int state) {
        if (weakDelegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* conversationId = [NSString stringWithUTF8String:conversation_id.c_str()];
            NSString* jamiId = [NSString stringWithUTF8String:peer.c_str()];
            NSString* messageId = [NSString stringWithUTF8String:message_id.c_str()];
            [weakDelegate messageStatusChanged:(MessageStatus)state for:messageId from:accountId to:jamiId in: conversationId];
        }
    }));

    confHandlers
        .insert(exportable_callback<ConfigurationSignal::RegisteredNameFound>([weakDelegate = Adapter.delegate](const std::string& account_id,
                                                                                  const std::string& requested_name,
                                                                                  int state,
                                                                                  const std::string address,
                                                                                  const std::string& name) {
            if (weakDelegate) {
                LookupNameResponse* response = [LookupNameResponse new];
                response.accountId = [NSString stringWithUTF8String:account_id.c_str()];
                response.state = (LookupNameState)state;
                response.address = [NSString stringWithUTF8String:address.c_str()];
                response.name = [NSString stringWithUTF8String:name.c_str()];
                response.requestedName = [NSString stringWithUTF8String:requested_name.c_str()];
                [weakDelegate registeredNameFoundWith:response];
            }
        }));

    confHandlers
    .insert(exportable_callback<DataTransferSignal::DataTransferEvent>([weakDelegate = Adapter.delegate](const std::string& account_id,
                                                                           const std::string& conversation_id,
                                                                           const std::string& interaction_id,
                                                                           const std::string& file_id,
                                                                           int eventCode) {
        if(weakDelegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* conversationId = [NSString stringWithUTF8String:conversation_id.c_str()];
            NSString* fileId = [NSString stringWithUTF8String:file_id.c_str()];
            NSString* interactionId = [NSString stringWithUTF8String:interaction_id.c_str()];

            [weakDelegate dataTransferEventWithFileId:fileId
                                            withEventCode:eventCode
                                                accountId:accountId
                                           conversationId:conversationId
                                           interactionId:interactionId];
        }
    }));
    confHandlers.insert(exportable_callback<ConfigurationSignal::RegistrationStateChanged>([weakDelegate = Adapter.delegate](const std::string& account_id, const std::string& state, int detailsCode, const std::string& detailsStr) {
        if (weakDelegate) {
            auto accountId = [NSString stringWithUTF8String:account_id.c_str()];
            auto stateStr = [NSString stringWithUTF8String:state.c_str()];
            [weakDelegate registrationStateChangedFor:accountId state:stateStr];
        }
    }));
    registerSignalHandlers(confHandlers);
}

#pragma mark - AdapterDelegate

+ (id<AdapterDelegate>)delegate {
    return _delegate;
}

+ (void)setDelegate:(id<AdapterDelegate>)delegate {
    _delegate = delegate;
}

- (id)init {
    self = [super init];
    return self;
}

- (BOOL)initDaemon {

    if (initialized()) {
        return YES;
    }

    if (![[NSThread currentThread] isMainThread]) {
        __block BOOL success;
        dispatch_sync(dispatch_get_main_queue(), ^{
            success = [self initDaemonInternal];
        });
        return success;
    } else {
        return [self initDaemonInternal];
    }
}

- (BOOL)initDaemonInternal {
#if DEBUG
    int flag = LIBJAMI_FLAG_DEBUG | LIBJAMI_FLAG_CONSOLE_LOG | LIBJAMI_FLAG_SYSLOG | LIBJAMI_FLAG_NO_LOCAL_MEDIA;
#else
    int flag = LIBJAMI_FLAG_NO_LOCAL_MEDIA;
#endif

    BOOL result = init(static_cast<InitFlag>(flag));
    return result;
}

- (BOOL)startDaemon {
    [self registerSignals];

    if (!initialized()) {
        if (![[NSThread currentThread] isMainThread]) {
            __block BOOL success;
            dispatch_sync(dispatch_get_main_queue(), ^{
                success = [self startDaemonInternal];
            });
            return success;
        } else {
            return [self startDaemonInternal];
        }
    }

    return NO;
}

- (BOOL)startDaemonInternal {
    BOOL result = start();
    return result;
}

- (void)cleanup {
    unregisterSignalHandlers();
    confHandlers.clear();
}

- (NSArray *)getAccountList {
    auto accountVector = libjami::getAccountList();

    NSArray *accountArray = [Utils vectorToArray:accountVector];

    return accountArray;
}

- (void)setAccountActive:(NSString *)accountID
                  active:(bool)active {
    setAccountActive(std::string([accountID UTF8String]), active, true);
}

- (void)pushNotificationReceived:(NSString*)from message:(NSDictionary*)data {
    pushNotificationReceived(std::string([from UTF8String]), [Utils dictionnaryToMap:data]);
}

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

- (NSDataTransferError)dataTransferInfoWithId:(NSString*)fileId
                                         accountId:(NSString*)accountId
                                          withInfo:(NSDataTransferInfo*)info {
    std::string filePath;
    int64_t size;
    int64_t progress;
    auto error = (NSDataTransferError)fileTransferInfo(std::string([accountId UTF8String]), std::string([info.conversationId UTF8String]), std::string([fileId UTF8String]), filePath, size, progress);
    info.totalSize = size;
    info.bytesProgress = progress;
    info.path = [NSString stringWithUTF8String: filePath.c_str()];
    return error;
}

- (void)lookupAddressWithAccount:(NSString*)account nameserver:(NSString*)nameserver address:(NSString*)address {
    lookupAddress(std::string([account UTF8String]), std::string([nameserver UTF8String]), std::string([address UTF8String]));
}

- (NSDictionary *)getAccountDetails:(NSString *)accountID {
    auto accDetails = getAccountDetails(std::string([accountID UTF8String]));
    return [Utils mapToDictionnary:accDetails];
}

- (NSMutableDictionary<NSString*,NSString*>*)getConversationInfoForAccount:(NSString*) accountId conversationId:(NSString*) conversationId {
    return [Utils mapToDictionnary: conversationInfos(std::string([accountId UTF8String]), std::string([conversationId UTF8String]))];
}

- (NSArray<NSDictionary<NSString*,NSString*>*>*)getConversationMembers:(NSString*) accountId conversationId:(NSString*) conversationId {
    return [Utils vectorOfMapsToArray: getConversationMembers(std::string([accountId UTF8String]), std::string([conversationId UTF8String]))];
}

@end
