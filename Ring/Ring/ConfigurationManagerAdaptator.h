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

#import <Foundation/Foundation.h>

@interface ConfigurationManagerAdaptator : NSObject

+ (id)sharedManager;

- (void) registerConfigurationHandler;

- (NSArray*) getAccountList;
- (NSMutableDictionary*) getAccountTemplate: (NSString*) accountType;
- (NSString*) addAccount: (NSDictionary*) details;
- (void) removeAccount: (NSString*) accountID;
- (void) setAccountActive: (NSString*) accountID : (bool) active;
- (uint64_t) sendAccountTextMessage: (NSString*) accountID : (NSString*) to : (NSDictionary*) payloads;
- (NSDictionary*) getAccountDetails: (NSString*) accountID;
- (NSDictionary*) getVolatileAccountDetails: (NSString*) accountID;
- (void) setAccountDetails: (NSString*) accountID :  (NSDictionary*) details;
- (int) getMessageStatus: (uint64_t) msgID;
@end
