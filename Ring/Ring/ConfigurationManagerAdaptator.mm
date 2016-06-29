/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
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

#import "ConfigurationManagerAdaptator.h"
#import "Utils.h"

#import "dring/configurationmanager_interface.h"

@implementation ConfigurationManagerAdaptator

using namespace DRing;

#pragma mark Singleton Methods

+ (id)sharedManager {
    static ConfigurationManagerAdaptator *sharedMyManager = nil;
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

- (NSArray*) getAccountList
{
    auto accountVector = getAccountList();

    return [Utils vectorToArray:accountVector];
}

- (NSMutableDictionary*) getAccountTemplate: (NSString*) accountType
{
    auto accountTemplate = getAccountTemplate(std::string([accountType UTF8String]));

    return [Utils mapToDictionnary:accountTemplate];
}

- (NSString*) addAccount: (NSDictionary*) details
{
    auto accountID = addAccount([Utils dictionnaryToMap:details]);

    return [NSString stringWithUTF8String:accountID.c_str()];
}

- (void) removeAccount: (NSString*) accountID
{
    removeAccount(std::string([accountID UTF8String]));
}

- (void) setAccountActive: (NSString*) accountID : (bool) active
{
    setAccountActive(std::string([accountID UTF8String]), active);
}

- (uint64_t) sendAccountTextMessage: (NSString*) accountID : (NSString*) to : (NSDictionary*) payloads
{
    return sendAccountTextMessage(std::string([accountID UTF8String]), std::string([to UTF8String]),
                                  [Utils dictionnaryToMap:payloads]);
}

- (NSDictionary*) getAccountDetails: (NSString*) accountID
{
    auto accDetails = getAccountDetails(std::string([accountID UTF8String]));
    return [Utils mapToDictionnary:accDetails];
}

- (NSDictionary*) getVolatileAccountDetails: (NSString*) accountID
{
    auto volatileDetails = getVolatileAccountDetails(std::string([accountID UTF8String]));
    return [Utils mapToDictionnary:volatileDetails];
}

- (void) setAccountDetails: (NSString*) accountID :  (NSDictionary*) details
{
    setAccountDetails(std::string([accountID UTF8String]), [Utils dictionnaryToMap:details]);
}

- (int) getMessageStatus:(uint64_t) msgID
{
    return getMessageStatus(msgID);
}

- (void) registerConfigurationHandler
{
    std::map<std::string, std::shared_ptr<CallbackWrapperBase>> confHandlers;
    
    confHandlers.insert(exportable_callback<ConfigurationSignal::IncomingAccountMessage>(
                                                                                         [&](const std::string& account_id,
                                                                                             const std::string& from,
                                                                                             const std::map<std::string, std::string>& payloads) {
        
        NSDictionary* userInfo = @{@"accountID": [NSString stringWithUTF8String:account_id.c_str()],
                                   @"from": [NSString stringWithUTF8String:from.c_str()],
                                   @"payloads": [Utils mapToDictionnary:payloads]};
        
        NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:@"IncomingAccountMessage" object:self userInfo:userInfo];
    }));
    
    confHandlers.insert(exportable_callback<ConfigurationSignal::AccountsChanged>([&](){
        NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:@"AccountsChanged" object:[ConfigurationManagerAdaptator sharedManager]];
    }));
    
    registerConfHandlers(confHandlers);
}

@end
