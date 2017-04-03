/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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

#import "AccountAdapter.h"
#import "Utils.h"

#import "dring/configurationmanager_interface.h"

@implementation AccountAdapter

using namespace DRing;

#pragma mark Singleton Methods
+ (instancetype)sharedManager {
    static AccountAdapter* sharedMyManager = nil;
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
    confHandlers.insert(exportable_callback<ConfigurationSignal::AccountsChanged>([&]() {
        //~ Using sharedManager to avoid as possible to retain self in the block.
        if ([[AccountAdapter sharedManager] delegate]) {
            [[[AccountAdapter sharedManager] delegate] accountsChanged];
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::RegisteredNameFound>([&](const std::string& account_id,
                                                                                          int state,
                                                                                          const std::string&address,
                                                                                          const std::string& name) {
        if ([[AccountAdapter sharedManager] delegate]) {
            [[[AccountAdapter sharedManager] delegate]
             registeredNameFoundWith:[NSString stringWithUTF8String:account_id.c_str()]
             state:(LookupNameState)state
             address:[NSString stringWithUTF8String:address.c_str()]
             name:[NSString stringWithUTF8String:name.c_str()]];
        }
    }));

    registerConfHandlers(confHandlers);
}
#pragma mark -

#pragma mark Accessors
- (NSDictionary *)getAccountDetails:(NSString *)accountID {
    auto accDetails = getAccountDetails(std::string([accountID UTF8String]));
    return [Utils mapToDictionnary:accDetails];
}

- (NSDictionary *)getVolatileAccountDetails:(NSString *)accountID {
    auto volatileDetails = getVolatileAccountDetails(std::string([accountID UTF8String]));
    return [Utils mapToDictionnary:volatileDetails];
}

- (void)setAccountDetails:(NSString *)accountID
                  details:(NSDictionary *)details {
    setAccountDetails(std::string([accountID UTF8String]),[Utils dictionnaryToMap:details]);
}

- (void)setAccountActive:(NSString *)accountID
                  active:(bool)active {
    setAccountActive(std::string([accountID UTF8String]), active);
}

- (NSArray *)getAccountList {
    auto accountVector = getAccountList();
    return [Utils vectorToArray:accountVector];
}

- (NSString *)addAccount:(NSDictionary *)details {
    auto accountID = addAccount([Utils dictionnaryToMap:details]);
    return [NSString stringWithUTF8String:accountID.c_str()];
}

- (void)removeAccount:(NSString *)accountID {
    removeAccount(std::string([accountID UTF8String]));
}

- (NSMutableDictionary *)getAccountTemplate:(NSString *)accountType {
    auto accountTemplate = getAccountTemplate(std::string([accountType UTF8String]));
    return [Utils mapToDictionnary:accountTemplate];
}

- (void)lookupNameWithAccount:(NSString*)account nameserver:(NSString*)nameserver name:(NSString*)name  {
    lookupName(std::string([account UTF8String]),std::string([nameserver UTF8String]),std::string([name UTF8String]));
}

#pragma mark -

@end
