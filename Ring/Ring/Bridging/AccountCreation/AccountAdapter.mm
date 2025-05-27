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

#import "jami/configurationmanager_interface.h"
#import "RegistrationResponse.h"

@implementation AccountAdapter

using namespace libjami;

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

    confHandlers.insert(exportable_callback<ConfigurationSignal::AccountDetailsChanged>([&](const std::string& account_id,
                                                                                            const std::map<std::string, std::string>& details) {
        if (AccountAdapter.delegate) {
            auto accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSMutableDictionary* detailsDict = [Utils mapToDictionnary: details];
            [AccountAdapter.delegate accountDetailsChangedWithAccountId: accountId details: detailsDict];
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::VolatileDetailsChanged>([&](const std::string& account_id,
                                                                                             const std::map<std::string, std::string>& details) {
        if (AccountAdapter.delegate) {
            auto accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSMutableDictionary* detailsDict = [Utils mapToDictionnary: details];
            [AccountAdapter.delegate accountVoaltileDetailsChangedWithAccountId: accountId details: detailsDict];
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::RegistrationStateChanged>([&](const std::string& account_id, const std::string& state, int detailsCode, const std::string& detailsStr) {
        if (AccountAdapter.delegate) {
            auto accountId = [NSString stringWithUTF8String:account_id.c_str()];
            auto stateStr = [NSString stringWithUTF8String:state.c_str()];
            [AccountAdapter.delegate registrationStateChangedFor:accountId state:stateStr];
        }
    }));

    // Add new handlers for device-related signals
    confHandlers.insert(exportable_callback<ConfigurationSignal::AddDeviceStateChanged>([&](const std::string& account_id,
                                                                                            uint32_t op_id,
                                                                                            int state,
                                                                                            const std::map<std::string, std::string>& detail) {
        if (AccountAdapter.delegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSMutableDictionary* detailsDict = [Utils mapToDictionnary:detail];
            [AccountAdapter.delegate addDeviceStateChangedWithAccountId:accountId
                                                                   opId:op_id
                                                                  state:state
                                                                details:detailsDict];
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::DeviceAuthStateChanged>([&](const std::string& account_id,
                                                                                             int state,
                                                                                             const std::map<std::string, std::string>& detail) {
        if (AccountAdapter.delegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSMutableDictionary* detailsDict = [Utils mapToDictionnary:detail];
            [AccountAdapter.delegate deviceAuthStateChangedWithAccountId:accountId
                                                                   state:state
                                                                 details:detailsDict];
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
    setAccountActive(std::string([accountID UTF8String]), active, true);
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
    return revokeDevice(std::string([accountID UTF8String]), std::string([deviceId UTF8String]), "password", std::string([password UTF8String]));
}

- (void)enableAccount:(NSString *)accountId active:(BOOL)active {
    sendRegister(std::string([accountId UTF8String]), active);
}

- (void)provideAccountAuthentication:(NSString *)accountId password:(NSString *)password {
    provideAccountAuthentication(std::string([accountId UTF8String]), std::string([password UTF8String]), "password");
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
    return true;//exportOnRing(std::string([accountID UTF8String]), std::string([password UTF8String]));
}

- (uint32_t)addDevice:(NSString *)accountId
           token:(NSString *)token {
    return addDevice(std::string([accountId UTF8String]), std::string([token UTF8String]));
}

- (void)confirmAddDevice:(NSString *)accountId
                operationId:(uint32_t)operationId {
    confirmAddDevice(std::string([accountId UTF8String]), operationId);
}

- (void)cancelAddDevice:(NSString *)accountId
             operationId:(uint32_t)operationId {
    cancelAddDevice(std::string([accountId UTF8String]), operationId);
}

- (void)pushNotificationReceived:(NSString*)from message:(NSDictionary*)data {
    pushNotificationReceived(std::string([from UTF8String]), [Utils dictionnaryToMap:data]);
}
- (void)setPushNotificationToken: (NSString*)token {
    setPushNotificationToken(std::string([token UTF8String]));
}

- (void)setPushNotificationConfig: (NSMutableDictionary *) config {
    setPushNotificationConfig([Utils dictionnaryToMap:config]);
}

- (void)setPushNotificationTopic:(NSString*)topic {
    setPushNotificationTopic(std::string([topic UTF8String]));
}

- (BOOL)passwordIsValid:(NSString *)accountId password:(NSString *)password {
    return isPasswordValid(std::string([accountId UTF8String]), std::string([password UTF8String]));
}

- (BOOL)changeAccountPassword:(NSString *)accountId
                  oldPassword:(NSString *)oldpassword
                  newPassword:(NSString *)newPassword {
    return changeAccountPassword(std::string([accountId UTF8String]),
                                 std::string([oldpassword UTF8String]),
                                 std::string([newPassword UTF8String]));
}

-(void)updateProfile:(NSString *)accountId
         displayName:(NSString *)displayName
              avatar:(NSString *)avatar
            fileType:(NSString *)fileType {
    updateProfile(std::string([accountId UTF8String]),
                  std::string([displayName UTF8String]),
                  std::string([avatar UTF8String]),
                  std::string([fileType UTF8String]), 1);
}

-(void)setAccountsActive:(BOOL) active {
    auto accounts = getAccountList();
    for(auto account: accounts) {
        setAccountActive(account, active, true);
    }
}

- (BOOL)exportToFileWithAccountId:(NSString *)accountId
              destinationPath:(NSString *)destinationPath
                       scheme:(NSString *)scheme
                     password:(NSString *)password {
    return exportToFile(std::string([accountId UTF8String]),
                        std::string([destinationPath UTF8String]),
                        std::string([scheme UTF8String]),
                        std::string([password UTF8String]));
}

@end
