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

    dataTransferHandlers.insert(exportable_callback<DataTransferSignal::DataTransferEvent>([&](const DataTransferId& transferId, int eventCode) {
        if(DataTransferAdapter.delegate) {
            [DataTransferAdapter.delegate dataTransferEventWithTransferId:(UInt64)transferId withEventCode:(NSInteger)eventCode];
        }
    }));

    registerDataXferHandlers(dataTransferHandlers);
}

#pragma mark API calls

- (NSArray*) dataTransferList {
    std::vector<DataTransferId> transferList = dataTransferList();
    NSMutableArray *retVal = [[NSMutableArray alloc] init];
    for(auto const& tid: transferList) {
        [retVal addObject:[NSNumber numberWithUnsignedLongLong:tid]];
    }
    return [retVal copy];
}

- (NSDataTransferError) sendFileWithInfo:(NSDataTransferInfo*)info
                        withTransferId:(UInt64*)transferId {
    DataTransferInfo transferInfo = {
        std::string([info->accountId UTF8String]),
        (DataTransferEventCode)info->lastEvent,
        static_cast<uint32_t>(info->flags),
        static_cast<int64_t>(info->totalSize),
        static_cast<int64_t>(info->bytesProgress),
        std::string([info->peer UTF8String]),
        std::string([info->displayName UTF8String]),
        std::string([info->path UTF8String]),
        std::string([info->mimetype UTF8String]),
    };
    return (NSDataTransferError)sendFile(transferInfo, *transferId);
}

- (NSDataTransferError) acceptFileTransferWithId:(UInt64)transferId
                                  withFilePath:(NSString*)filePath
                                    withOffset:(SInt64)offset {
    return (NSDataTransferError)acceptFileTransfer(transferId,
                                                   std::string([filePath UTF8String]),
                                                   offset);
}

- (NSDataTransferError) cancelDataTransferWithId:(UInt64)transferId {
    return (NSDataTransferError)cancelDataTransfer(transferId);
}

- (NSDataTransferError) dataTransferInfoWithId:(UInt64)transferId
                                    withInfo:(NSDataTransferInfo*)info {
    DataTransferInfo transferInfo;
    auto err = (NSDataTransferError)dataTransferInfo(transferId, transferInfo);
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

- (NSDataTransferError) dataTransferBytesProgressWithId:(UInt64)transferId
                                            withTotal:(SInt64*)total
                                         withProgress:(SInt64*)progress {
    return (NSDataTransferError)dataTransferBytesProgress(transferId, *total, *progress);
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
