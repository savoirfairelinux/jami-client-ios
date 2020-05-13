/*
 *  Copyright (C) 2016-2019 Savoir-faire Linux Inc.
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
#import "RegistrationResponse.h"

@implementation AccountAdapter

using namespace DRing;

/// Static delegate that will receive the propagated daemon events
static id <AccountAdapterDelegate> _delegate;

#pragma mark Init
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
        if (AccountAdapter.delegate) {
            [AccountAdapter.delegate accountsChanged];
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::RegistrationStateChanged>([&](const std::string& account_id, const std::string& state, int detailsCode, const std::string& detailsStr) {
        if (AccountAdapter.delegate) {
            RegistrationResponse* response = [RegistrationResponse new];
            response.accountId = [NSString stringWithUTF8String:account_id.c_str()];
            response.state = [NSString stringWithUTF8String:state.c_str()];
            response.detailsCode = (RegistrationResponseDetailsCode)detailsCode;
            response.details = [NSString stringWithUTF8String:detailsStr.c_str()];
            [AccountAdapter.delegate registrationStateChangedWith:response];
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::ExportOnRingEnded>([&](const std::string& account_id, int state, const std::string& pin) {
        if (AccountAdapter.delegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSInteger stateN = state;
            NSString* pinN = [NSString stringWithUTF8String:pin.c_str()];
            [AccountAdapter.delegate exportOnRingEndedFor:accountId state:stateN pin:pinN];
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::KnownDevicesChanged>([&](const std::string& account_id, const std::map<std::string, std::string>& devices) {
        if (AccountAdapter.delegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSMutableDictionary* knDev = [Utils mapToDictionnary:devices];
            [AccountAdapter.delegate knownDevicesChangedFor:accountId devices:knDev];
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::DeviceRevocationEnded>([&](const std::string& account_id, const std::string& device, int status) {
        if (AccountAdapter.delegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSInteger state = status;
            NSString* deviceId = [NSString stringWithUTF8String:device.c_str()];
            [AccountAdapter.delegate deviceRevocationEndedFor: accountId state: state deviceId: deviceId];
        }
    }));

    confHandlers
    .insert(exportable_callback<ConfigurationSignal::AccountAvatarReceived>([&](const std::string& account_id, const std::string& photo) {
        if (AccountAdapter.delegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* avatarPhoto = [NSString stringWithUTF8String:photo.c_str()];
            [AccountAdapter.delegate receivedAccountPhotoFor:accountId photo:avatarPhoto];
        }
    }));
    confHandlers
       .insert(exportable_callback<ConfigurationSignal::MigrationEnded>([&](const std::string& account_id, const std::string& status) {
           if (AccountAdapter.delegate) {
               NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
               NSString* migaretionStatus = [NSString stringWithUTF8String:status.c_str()];
               [AccountAdapter.delegate migrationEndedFor:accountId status:migaretionStatus];
           }
       }));
    registerSignalHandlers(confHandlers);
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

- (void)setAccountCredentials:(NSString *)accountID
                      credentials:(NSArray*) credentials {
    setCredentials(std::string([accountID UTF8String]), [Utils arrayOfDictionnarisToVectorOfMap:credentials]);
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

- (NSArray *)getCredentials:(NSString *)accountID {
    auto credentials = getCredentials(std::string([accountID UTF8String]));
    return [Utils vectorOfMapsToArray:credentials];
}

- (NSDictionary *)getKnownRingDevices:(NSString *)accountID {
    auto ringDevices = getKnownRingDevices(std::string([accountID UTF8String]));
    return [Utils mapToDictionnary:ringDevices];
}

- (bool)revokeDevice:(NSString *)accountID
            password:(NSString *)password
            deviceId:(NSString *)deviceId
{
    return revokeDevice(std::string([accountID UTF8String]),std::string([password UTF8String]), std::string([deviceId UTF8String]));
}

#pragma mark -

#pragma mark AccountAdapterDelegate
+ (id <AccountAdapterDelegate>)delegate {
    return _delegate;
}

+ (void) setDelegate:(id<AccountAdapterDelegate>)delegate {
    _delegate = delegate;
}
#pragma mark -

#pragma mark -

- (Boolean)exportOnRing:(NSString *)accountID
               password: (NSString *)password {
    return exportOnRing(std::string([accountID UTF8String]), std::string([password UTF8String]));
}

- (void)pushNotificationReceived:(NSString*)from message:(NSDictionary*)data {
    pushNotificationReceived(std::string([from UTF8String]), [Utils dictionnaryToMap:data]);
}
- (void)setPushNotificationToken: (NSString*)token {
    setPushNotificationToken(std::string([token UTF8String]));
}
- (BOOL)enableBoothMode:(NSString *)accountId password:(NSString *)password enable:(BOOL)enable {
    return enableBoothMode(std::string([accountId UTF8String]), std::string([password UTF8String]), enable);
}

- (BOOL)changeAccountPassword:(NSString *)accountId
                  oldPassword:(NSString *)oldpassword
                  newPassword:(NSString *)newPassword {
    return changeAccountPassword(std::string([accountId UTF8String]),
                                 std::string([oldpassword UTF8String]),
                                 std::string([newPassword UTF8String]));
    
}

@end
