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

#import "DataTransferAdapter.h"
#import "Utils.h"
#import "dring/datatransfer_interface.h"
#import "Ring-Swift.h"

@implementation NSDataTransferInfo
@synthesize accountId, lastEvent, flags, totalSize, bytesProgress, peer, displayName, path, mimetype;

- (id) init {
    if (self = [super init]) {
        self->lastEvent = invalid;
        self->flags = 0;
        self->totalSize = 0;
        self->bytesProgress = 0;
    }
    return self;
};

@end

using namespace DRing;

@implementation DataTransferAdapter

static id <DataTransferAdapterDelegate> _delegate;

#pragma mark Init

- (id)init {
    if (self = [super init]) {
        [self registerDataTransferHandlers];
    }
    return self;
}

#pragma mark -

#pragma mark Callbacks registration

- (void)registerDataTransferHandlers {
    
    std::map<std::string, std::shared_ptr<CallbackWrapperBase>> dataTransferHandlers;
    
    dataTransferHandlers
    .insert(exportable_callback<DataTransferSignal::DataTransferEvent>([&](const std::string& accountId,
                                                                           const std::string& conversationId,
                                                                           const std::string& interactionId,
                                                                           const std::string& fileId,
                                                                           int eventCode) {
        if(DataTransferAdapter.delegate) {
            
        }
    }));
    
    registerSignalHandlers(dataTransferHandlers);
}

#pragma mark API calls

- (void)sendFileWithName:(NSString*)displayName
               accountId:(NSString*)accountId
          conversationId:(NSString*)conversationId
            withFilePath:(NSString*)filePath
            withFilePath:(NSString*)parent {
    sendFile(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([filePath UTF8String]), std::string([displayName UTF8String]), std::string([parent UTF8String]));
}

- (NSDataTransferError)acceptFileTransferWithId:(NSString*)fileId
                                      accountId:(NSString*)accountId
                                   withFilePath:(NSString*)filePath {
    return (NSDataTransferError)acceptFileTransfer(std::string([accountId UTF8String]),
                                                   std::string([fileId UTF8String]),
                                                   std::string([filePath UTF8String]));
}

- (NSDataTransferError)cancelDataTransferWithId:(NSString*)fileId
                                      accountId:(NSString*)accountId
                                 conversationId:(NSString*)conversationId {
    return (NSDataTransferError)cancelDataTransfer(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([fileId UTF8String]));
}

- (NSDataTransferError)dataTransferInfoWithId:(NSString*)fileId
                                    accountId:(NSString*)accountId
                                     withInfo:(NSDataTransferInfo*)info {
    DataTransferInfo transferInfo;
    auto err = (NSDataTransferError)dataTransferInfo(std::string([accountId UTF8String]), std::string([fileId UTF8String]), transferInfo);
    info->accountId = [NSString stringWithUTF8String:transferInfo.accountId.c_str()];
    info->lastEvent = (NSDataTransferEventCode)transferInfo.lastEvent;
    info->flags = transferInfo.flags;
    info->totalSize = transferInfo.totalSize;
    info->bytesProgress = transferInfo.bytesProgress;
    info->peer = [NSString stringWithUTF8String:transferInfo.peer.c_str()];
    info->displayName = [NSString stringWithUTF8String:transferInfo.displayName.c_str()];
    info->path =[NSString stringWithUTF8String:transferInfo.path.c_str()];
    info->mimetype = [NSString stringWithUTF8String:transferInfo.mimetype.c_str()];
    return err;
}

- (NSDataTransferError)dataTransferBytesProgressWithId:(NSString*)fileId
                                             withTotal:(int64_t*)total
                                          withProgress:(int64_t*)progress
                                             accountId:(NSString*)accountId
                                        conversationId:(NSString*)conversationId
                                                  path:(NSString*)path {
    std::string filePath = std::string([path UTF8String]);
    return (NSDataTransferError)fileTransferInfo(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([fileId UTF8String]), filePath, *total, *progress);
}

#pragma mark AccountAdapterDelegate

+ (id <DataTransferAdapterDelegate>)delegate {
    return _delegate;
}

+ (void) setDelegate:(id<DataTransferAdapterDelegate>)delegate {
    _delegate = delegate;
}

#pragma mark -

@end
