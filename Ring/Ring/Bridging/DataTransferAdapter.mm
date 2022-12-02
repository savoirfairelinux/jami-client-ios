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
#import "jami/datatransfer_interface.h"
#import "Ring-Swift.h"

@implementation NSDataTransferInfo
@synthesize accountId, lastEvent, flags, totalSize, bytesProgress, peer, displayName, path, mimetype, conversationId;

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

using namespace libjami;

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
    .insert(exportable_callback<DataTransferSignal::DataTransferEvent>([&](const std::string& account_id,
                                                                           const std::string& conversation_id,
                                                                           const std::string& interaction_id,
                                                                           const std::string& file_id,
                                                                           int eventCode) {
        if(DataTransferAdapter.delegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* conversationId = [NSString stringWithUTF8String:conversation_id.c_str()];
            NSString* fileId = [NSString stringWithUTF8String:file_id.c_str()];
            NSString* interactionId = [NSString stringWithUTF8String:interaction_id.c_str()];
            [DataTransferAdapter.delegate dataTransferEventWithFileId: fileId withEventCode: eventCode accountId: accountId conversationId: conversationId interactionId: interactionId];
        }
    }));
    
    registerSignalHandlers(dataTransferHandlers);
}

#pragma mark API calls

///swarm conversations
- (void)sendSwarmFileWithName:(NSString*)displayName
                    accountId:(NSString*)accountId
               conversationId:(NSString*)conversationId
                 withFilePath:(NSString*)filePath
                       parent:(NSString*)parent {
    sendFile(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([filePath UTF8String]), std::string([displayName UTF8String]), std::string([parent UTF8String]));
}

- (NSDataTransferError)swarmTransferProgressWithId:(NSString*)fileId
                                         accountId:(NSString*)accountId
                                          withInfo:(NSDataTransferInfo*)info {
    std::string filePath;
    int64_t size;
    int64_t progress;
    auto error = (NSDataTransferError)fileTransferInfo(std::string([accountId UTF8String]), std::string([info.conversationId UTF8String]), std::string([fileId UTF8String]), filePath, size, progress);
    info.totalSize = size;
    info.bytesProgress = progress;
    info.path = [NSString stringWithUTF8String: filePath.c_str()];
    return error;
}

- (bool)downloadSwarmTransferWithFileId:(NSString*)fileId
                              accountId:(NSString*)accountId
                         conversationId:(NSString*)conversationId
                          interactionId:(NSString*)interactionId
                           withFilePath:(NSString*)filePath {
    return downloadFile(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([interactionId UTF8String]), std::string([fileId UTF8String]), std::string([filePath UTF8String]));
}

///swarm  and non swarm conversations
- (NSDataTransferError)cancelDataTransferWithId:(NSString*)fileId
                                      accountId:(NSString*)accountId
                                 conversationId:(NSString*)conversationId {
    return (NSDataTransferError)cancelDataTransfer(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([fileId UTF8String]));
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
