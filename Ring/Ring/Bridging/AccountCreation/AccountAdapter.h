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

#import <Foundation/Foundation.h>

/**
 Forward declaration of the Swift delegate.
 We have to do this because the Ring-Swift.h generated file can't be imported from a .h file.
 The plain import is done in the .mm file.
 */
@protocol AccountAdapterDelegate;

/**
 Class making the bridge between the Ring Daemon and the application.
 It only concerns "Accounts related" features.
 Its responsabilities:
 - register to daemon callbacks,
 - forward callbacks to the application thanks to the integrated delegation pattern,
 - forward instructions coming from the app to the daemon
 */
@interface AccountAdapter : NSObject

/**
 Delegate where all the accounts events will be forwarded.
 */
@property (class, nonatomic, weak) id <AccountAdapterDelegate> delegate;

- (NSDictionary *)getAccountDetails:(NSString *)accountID;

- (NSDictionary *)getVolatileAccountDetails:(NSString *)accountID;

- (void)setAccountDetails:(NSString *)accountID
                  details:(NSDictionary *)details;

- (void)setAccountCredentials:(NSString *)accountID
                  credentials:(NSArray *)credentials;

- (void)setAccountActive:(NSString *)accountID
                  active:(bool)active;

- (NSMutableDictionary *)getAccountTemplate:(NSString *)accountType;

- (NSString *)addAccount:(NSDictionary *)details;

- (void)removeAccount:(NSString *)accountID;

- (NSArray *)getAccountList;

- (NSArray *)getCredentials:(NSString *)accountID;

- (NSDictionary *)getKnownRingDevices:(NSString *)accountID;

- (bool)revokeDevice:(NSString *)accountID
            password:(NSString *)password
            deviceId:(NSString *)deviceId;

- (Boolean)exportOnRing:(NSString *)accountID
               password: (NSString *)password;

- (void)pushNotificationReceived:(NSString *) from message:(NSDictionary*) data;
- (void)setPushNotificationToken: (NSString *) token;
- (BOOL)enableBoothMode:(NSString *)accountId password:(NSString *)password enable:(BOOL)enable;
- (BOOL)changeAccountPassword:(NSString *)accountId
                  oldPassword:(NSString *)oldpassword
                  newPassword:(NSString *)newPassword;

@end
