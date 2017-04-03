/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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
#import "BlockchainAdapter.h"
#import "Utils.h"
#import "dring/configurationmanager_interface.h"


@implementation BlockchainAdapter

using namespace DRing;

#pragma mark Singleton Methods
+ (instancetype)sharedManager {
    static BlockchainAdapter* sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
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
        if ([[BlockchainAdapter sharedManager] delegate]) {
            [[[BlockchainAdapter sharedManager] delegate]
             registeredNameFoundWith:[NSString stringWithUTF8String:account_id.c_str()]
             state:(LookupNameState)state
             address:[NSString stringWithUTF8String:address.c_str()]
             name:[NSString stringWithUTF8String:name.c_str()]];
        }
    }));

    registerConfHandlers(confHandlers);
}
#pragma mark -

- (void)lookupNameWithAccount:(NSString*)account nameserver:(NSString*)nameserver name:(NSString*)name  {
    lookupName(std::string([account UTF8String]),std::string([nameserver UTF8String]),std::string([name UTF8String]));
}

@end
