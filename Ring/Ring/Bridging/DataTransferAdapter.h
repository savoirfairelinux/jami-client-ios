/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
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

#import "ObjcTypes.h"
#import <Foundation/Foundation.h>

@protocol DataTransferAdapterDelegate;

@interface DataTransferAdapter : NSObject

@property (class, nonatomic, weak) id <DataTransferAdapterDelegate> delegate;

///swarm conversations
- (void)sendSwarmFileWithName:(NSString*)displayName
                    accountId:(NSString*)accountId
               conversationId:(NSString*)conversationId
                 withFilePath:(NSString*)filePath
                       parent:(NSString*)parent;

- (NSDataTransferError) dataTransferInfoWithId:(NSString*)fileId
                                          accountId:(NSString*)accountId
                                           withInfo:(NSDataTransferInfo*)info;

- (bool)downloadSwarmTransferWithFileId:(NSString*)fileId
                              accountId:(NSString*)accountId
                         conversationId:(NSString*)conversationId
                          interactionId:(NSString*)interactionId
                           withFilePath:(NSString*)filePath;

///swarm and non swarm conversations
- (NSDataTransferError)cancelDataTransferWithId:(NSString*)fileId
                                      accountId:(NSString*)accountId
                                 conversationId:(NSString*)conversationId;
@end
