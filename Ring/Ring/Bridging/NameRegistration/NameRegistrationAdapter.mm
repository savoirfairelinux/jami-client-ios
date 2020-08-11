/*
 *  Copyright (C) 2017-2020 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
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

#import "Ring-Swift.h"
#import "NameRegistrationAdapter.h"
#import "Utils.h"
#import "dring/configurationmanager_interface.h"
#import "LookupNameResponse.h"
#import "NameRegistrationResponse.h"
#import "UserSearchResponse.h"

@implementation NameRegistrationAdapter

using namespace DRing;

/// Static delegate that will receive the propagated daemon events
static id <NameRegistrationAdapterDelegate> _delegate;

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
        if (NameRegistrationAdapter.delegate) {
            LookupNameResponse* response = [LookupNameResponse new];
            response.accountId = [NSString stringWithUTF8String:account_id.c_str()];
            response.state = (LookupNameState)state;
            response.address = [NSString stringWithUTF8String:address.c_str()];
            response.name = [NSString stringWithUTF8String:name.c_str()];
            [NameRegistrationAdapter.delegate registeredNameFoundWith:response];
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::NameRegistrationEnded>([&](const std::string&account_id,
                                                                                            int state,
                                                                                            const std::string& name) {
        if (NameRegistrationAdapter.delegate) {
            NameRegistrationResponse* response = [NameRegistrationResponse new];
            response.accountId = [NSString stringWithUTF8String:account_id.c_str()];
            response.state = (NameRegistrationState)state;
            response.name = [NSString stringWithUTF8String:name.c_str()];
            [NameRegistrationAdapter.delegate nameRegistrationEndedWith:response];
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::UserSearchEnded>([&](const std::string&account_id,
                                                                                      int state,
                                                                                      const std::string&query,
                                                                                      const std::vector<std::map<std::string,std::string>>&results) {
        if (NameRegistrationAdapter.delegate) {
            UserSearchResponse* response = [UserSearchResponse new];
            response.accountId = [NSString stringWithUTF8String:account_id.c_str()];
            response.state = (UserSearchState)state;
            response.query = [NSString stringWithUTF8String:query.c_str()];
            response.results = [Utils vectorOfMapsToArray:results];
            [NameRegistrationAdapter.delegate userSearchEndedWith:response];
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

#pragma mark NameRegistrationAdapterDelegate
+ (id <NameRegistrationAdapterDelegate>)delegate {
    return _delegate;
}

+ (void) setDelegate:(id<NameRegistrationAdapterDelegate>)delegate {
    _delegate = delegate;
}
#pragma mark -

@end
