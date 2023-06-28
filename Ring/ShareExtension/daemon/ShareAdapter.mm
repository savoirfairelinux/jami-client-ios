/*
 * Copyright (C) 2023 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#import "ShareAdapter.h"
#import "ShareUtils.h"
#import "UIKit/UIKit.h"
#import "ShareExtension-Swift.h"

#import "jami/jami.h"
#import "jami/conversation_interface.h"
#import "jami/configurationmanager_interface.h"
#import "LookupNameResponse.h"
#import "NameRegistrationResponse.h"
#import "UserSearchResponse.h"
#import "jami/datatransfer_interface.h"

@implementation ShareAdapter

/// Static delegate that will receive the propagated daemon events
static id <NameRegistrationAdapterDelegate> _delegate;

using namespace libjami;

// Constants
const std::string fileSeparator = "/";
NSString* const certificates = @"certificates";
NSString* const crls = @"crls";
NSString* const ocsp = @"ocsp";
NSString* const nameCache = @"namecache";
NSString* const defaultNameServer = @"ns.jami.net";
std::string const nameServerConfiguration = "RingNS.uri";
NSString* const accountConfig = @"config.yml";

std::map<std::string, std::shared_ptr<CallbackWrapperBase>> confHandlers;
std::map<std::string, std::string> cachedNames;
std::map<std::string, std::string> nameServers;

#pragma mark AdapterDelegate
+ (id<NameRegistrationAdapterDelegate>)delegate
{
    return _delegate;
}

+ (void)setDelegate:(id<NameRegistrationAdapterDelegate>)delegate
{
    _delegate = delegate;
}

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
    registerSignalHandlers(confHandlers);
}

- (BOOL)start
{
    [self registerSignals];
    if (initialized() == true) {
        return true;
    }
#if DEBUG
    int flag = LIBJAMI_FLAG_CONSOLE_LOG | LIBJAMI_FLAG_DEBUG | LIBJAMI_FLAG_IOS_EXTENSION | LIBJAMI_FLAG_NO_AUTOSYNC | LIBJAMI_FLAG_NO_LOCAL_AUDIO;
#else
    int flag = LIBJAMI_FLAG_IOS_EXTENSION | LIBJAMI_FLAG_NO_AUTOSYNC | LIBJAMI_FLAG_NO_LOCAL_AUDIO;
#endif
    if (![[NSThread currentThread] isMainThread]) {
        __block bool success;
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (init(static_cast<InitFlag>(flag))) {
                success = start({});
            } else {
                success = false;
            }
        });
        return success;
    } else {
        if (init(static_cast<InitFlag>(flag))) {
            return start({});
        }
        return false;
    }
}

- (NSArray *)getAccountList {
    auto accountVector = getAccountList();
    return [ShareUtils vectorToArray:accountVector];
}

- (NSDictionary *)getAccountDetails:(NSString *)accountID {
    auto accDetails = getAccountDetails(std::string([accountID UTF8String]));
    return [ShareUtils mapToDictionnary:accDetails];
}

- (NSArray*)getSwarmConversationsForAccount:(NSString*) accountId {
    return [ShareUtils vectorToArray: getConversations(std::string([accountId UTF8String]))];
}

- (NSMutableDictionary<NSString*,NSString*>*)getConversationInfoForAccount:(NSString*) accountId conversationId:(NSString*) conversationId {
    return [ShareUtils mapToDictionnary: conversationInfos(std::string([accountId UTF8String]), std::string([conversationId UTF8String]))];
}

- (NSArray<NSDictionary<NSString*,NSString*>*>*)getConversationMembers:(NSString*) accountId conversationId:(NSString*) conversationId {
    return [ShareUtils vectorOfMapsToArray: getConversationMembers(std::string([accountId UTF8String]), std::string([conversationId UTF8String]))];
}

- (void)stop
{
    unregisterSignalHandlers();
    confHandlers.clear();
}

- (id)init {
    if (self = [super init]) {
        [self registerConfigurationHandler];
    }
    return self;
}
#pragma mark -

#pragma mark Callbacks registration
- (void)registerConfigurationHandler {
    std::map<std::string, std::shared_ptr<CallbackWrapperBase>> confHandlers;

    confHandlers.insert(exportable_callback<ConfigurationSignal::RegisteredNameFound>([&](const std::string&account_id,
                                                                                          int state,
                                                                                          const std::string address,
                                                                                          const std::string& name) {
        if (ShareAdapter.delegate) {
            LookupNameResponse* response = [LookupNameResponse new];
            response.accountId = [NSString stringWithUTF8String:account_id.c_str()];
            response.state = (LookupNameState)state;
            response.address = [NSString stringWithUTF8String:address.c_str()];
            response.name = [NSString stringWithUTF8String:name.c_str()];
            [ShareAdapter.delegate registeredNameFoundWith:response];
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::NameRegistrationEnded>([&](const std::string&account_id,
                                                                                            int state,
                                                                                            const std::string& name) {
        if (ShareAdapter.delegate) {
            NameRegistrationResponse* response = [NameRegistrationResponse new];
            response.accountId = [NSString stringWithUTF8String:account_id.c_str()];
            response.state = (NameRegistrationState)state;
            response.name = [NSString stringWithUTF8String:name.c_str()];
            [ShareAdapter.delegate nameRegistrationEndedWith:response];
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::UserSearchEnded>([&](const std::string&account_id,
                                                                                      int state,
                                                                                      const std::string&query,
                                                                                      const std::vector<std::map<std::string,std::string>>&results) {
        if (ShareAdapter.delegate) {
            UserSearchResponse* response = [UserSearchResponse new];
            response.accountId = [NSString stringWithUTF8String:account_id.c_str()];
            response.state = (UserSearchState)state;
            response.query = [NSString stringWithUTF8String:query.c_str()];
            response.results = [ShareUtils vectorOfMapsToArray:results];
            [ShareAdapter.delegate userSearchEndedWith:response];
        }
    }));

    registerSignalHandlers(confHandlers);
}
#pragma mark -

- (void)lookupNameWithAccount:(NSString*)account nameserver:(NSString*)nameserver name:(NSString*)name {
    lookupName(std::string([account UTF8String]),std::string([nameserver UTF8String]),std::string([name UTF8String]));
}

- (void)lookupAddressWithAccount:(NSString*)account nameserver:(NSString*)nameserver address:(NSString*)address {
    lookupAddress(std::string([account UTF8String]), std::string([nameserver UTF8String]), std::string([address UTF8String]));
}

- (void)registerNameWithAccount:(NSString*)account password:(NSString*)password name:(NSString*)name {
    registerName(std::string([account UTF8String]), std::string([password UTF8String]), std::string([name UTF8String]));
}

- (void)searchUserWithAccount:(NSString*)account query:(NSString*)query {
    searchUser(std::string([account UTF8String]), std::string([query UTF8String]));
}

- (uint32_t)loadConversationMessages:(NSString*) accountId conversationId:(NSString*) conversationId from:(NSString*)fromMessage size:(NSInteger)size {
    return loadConversationMessages(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([fromMessage UTF8String]), size);
}

///swarm conversations
- (void)sendSwarmFileWithName:(NSString*)displayName
                    accountId:(NSString*)accountId
               conversationId:(NSString*)conversationId
                 withFilePath:(NSString*)filePath
                       parent:(NSString*)parent {
    sendFile(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([filePath UTF8String]), std::string([displayName UTF8String]), std::string([parent UTF8String]));
}

@end
