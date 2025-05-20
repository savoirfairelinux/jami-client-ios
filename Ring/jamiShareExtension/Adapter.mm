/*
 *  Copyright (C) 2021-2022 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

#import <UIKit/UIKit.h>               // ✅ Required
#import "jamiShareExtension-Swift.h"
#import "Adapter.h"
#import "Utils.h"

#import "jami/jami.h"
#import "jami/configurationmanager_interface.h"
#import "jami/conversation_interface.h"
#import "jami/conversation_interface.h"

@implementation Adapter

static id<AdapterDelegate> _delegate;

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
constexpr auto ID_TIMEOUT = std::chrono::hours(24);

std::map<std::string, std::shared_ptr<CallbackWrapperBase>> confHandlers;
std::map<std::string, std::pair<std::string, std::string>> cachedNames;
std::map<std::string, std::string> nameServers;


#pragma mark Callbacks registration
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

#pragma mark Init
- (id)init {
    self = [super init];
    return self;
}

- (BOOL)initDaemon {
    printf("****hello****");
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
    int flag = LIBJAMI_FLAG_IOS_EXTENSION | LIBJAMI_FLAG_NO_AUTOSYNC | LIBJAMI_FLAG_NO_LOCAL_AUDIO | LIBJAMI_FLAG_CONSOLE_LOG | LIBJAMI_FLAG_DEBUG;
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



- (NSArray *)getAccountList {
    printf("Calling libjami::getAccountList...\n");

    auto accountVector = libjami::getAccountList(); // prevent recursion

    printf("Got account vector from libjami. Size: %zu\n", accountVector.size());

    // Optionally, print the contents of the accountVector
    for (size_t i = 0; i < accountVector.size(); ++i) {
        const auto& account = accountVector[i];
        printf("Account[%zu]: %s\n", i, account.c_str());
    }

    NSArray *accountArray = [Utils vectorToArray:accountVector];
    printf("Converted account vector to NSArray. Count: %lu\n", (unsigned long)[accountArray count]);

    return accountArray;
}

- (NSArray*)getSwarmConversationsForAccount:(NSString*) accountId {
    return [Utils vectorToArray: getConversations(std::string([accountId UTF8String]))];
}

@end
