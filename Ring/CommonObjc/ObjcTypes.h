/*
 *  Copyright (C) 2016-2019 Savoir-faire Linux Inc.
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
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301
 * USA.
 */

#import <Foundation/Foundation.h>

typedef NS_ENUM(int, MessageStatus)  {
    MessageStatusUnknown = 0,
    MessageStatusSending,
    MessageStatusSent,
    MessageStatusDisplayed,
    MessageStatusFailure,
    MessageStatusCanceled
};

typedef NS_ENUM(UInt32, NSDataTransferEventCode)  {
    invalid = 0,
    created,
    unsupported,
    wait_peer_acceptance,
    wait_host_acceptance,
    ongoing,
    finished,
    closed_by_host,
    closed_by_peer,
    invalid_pathname,
    unjoinable_peer
};

typedef NS_ENUM(UInt32, NSDataTransferError)  {
    success = 0,
    unknown,
    io,
    invalid_argument
};

typedef NS_ENUM(UInt32, NSDataTransferFlags)  {
    direction = 0
};

@interface NSDataTransferInfo: NSObject
{
@public
    NSString* accountId;
    NSDataTransferEventCode lastEvent;
    UInt32 flags;
    int64_t totalSize;
    int64_t bytesProgress;
    NSString* peer;
    NSString* displayName;
    NSString* path;
    NSString* mimetype;
    NSString* conversationId;
}
@property (strong, nonatomic) NSString* accountId;
@property (nonatomic) NSDataTransferEventCode lastEvent;
@property (nonatomic) UInt32 flags;
@property (nonatomic) int64_t totalSize;
@property (nonatomic) int64_t bytesProgress;
@property (strong, nonatomic) NSString* peer;
@property (strong, nonatomic) NSString* displayName;
@property (strong, nonatomic) NSString* path;
@property (strong, nonatomic) NSString* conversationId;
@property (strong, nonatomic) NSString* mimetype;
@end

@interface SwarmMessageWrap : NSObject

@property (nonatomic, strong) NSString* id;
@property (nonatomic, strong) NSString* type;
@property (nonatomic, strong) NSString* linearizedParent;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *>* body;
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, NSString *> *>* reactions;
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, NSString *> *>* editions;
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber* >* status;

@end
