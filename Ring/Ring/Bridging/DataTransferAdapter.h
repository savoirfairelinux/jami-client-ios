/*
 *  Copyright (C) 2018 Savoir-faire Linux Inc.
 *
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
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
    direction = 0 // 0: outgoing, 1: incoming
};

@interface NSDataTransferInfo: NSObject
{
@public
    NSString* accountId;
    NSDataTransferEventCode lastEvent;
    UInt32 flags;
    SInt64 totalSize;
    SInt64 bytesProgress;
    NSString* peer;
    NSString* displayName;
    NSString* path;
    NSString* mimetype;
}
@property (strong, nonatomic) NSString* accountId;
@property (nonatomic) NSDataTransferEventCode lastEvent;
@property (nonatomic) UInt32 flags;
@property (nonatomic) SInt64 totalSize;
@property (nonatomic) SInt64 bytesProgress;
@property (strong, nonatomic) NSString* peer;
@property (strong, nonatomic) NSString* displayName;
@property (strong, nonatomic) NSString* path;
@property (strong, nonatomic) NSString* mimetype;
@end

@protocol DataTransferAdapterDelegate;

@interface DataTransferAdapter : NSObject

@property (class, nonatomic, weak) id <DataTransferAdapterDelegate> delegate;

- (NSArray*)dataTransferList;
- (NSDataTransferError) sendFileWithInfo:(NSDataTransferInfo*)info withTransferId:(UInt64*)transferId;
- (NSDataTransferError) acceptFileTransferWithId:(UInt64)transferId withFilePath:(NSString*)filePath withOffset:(SInt64)offset;
- (NSDataTransferError) cancelDataTransferWithId:(UInt64)transferId;
- (NSDataTransferError) dataTransferInfoWithId:(UInt64)transferId withInfo:(NSDataTransferInfo*)info;
- (NSDataTransferError) dataTransferBytesProgressWithId:(UInt64)transferId withTotal:(SInt64*)total withProgress:(SInt64*)progress;

@end
