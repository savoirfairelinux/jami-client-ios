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

    using namespace DRing;

    std::map<std::string, std::shared_ptr<CallbackWrapperBase>> dataTransferHandlers;

    dataTransferHandlers.insert(exportable_callback<DataTransferSignal::DataTransferEvent>([&](const DataTransferId& transferId, int eventCode) {
        if(DataTransferAdapter.delegate) {
            [DataTransferAdapter.delegate dataTransferEventWithTransferId:(UInt64)transferId withEventCode:(NSInteger)eventCode];
        }
    }));

    registerDataXferHandlers(dataTransferHandlers);
}

#pragma mark API calls

- (NSArray*)dataTransferList {
    return nil;
}

- (NSDataTransferError) sendFileWithInfo:(NSDataTransferInfo*)info
                        withTransferId:(UInt64*)transferId {
    return NSDataTransferError::unknown;
}

- (NSDataTransferError) acceptFileTransferWithId:(UInt64)transferId
                                  withFilePath:(NSString*)filePath
                                    withOffset:(SInt64)offset {
    return NSDataTransferError::unknown;
}

- (NSDataTransferError) cancelDataTransferWithId:(UInt64)transferId {
    return NSDataTransferError::unknown;
}

- (NSDataTransferError) dataTransferInfoWithId:(UInt64)transferId
                                    withInfo:(NSDataTransferInfo*)info {
    return NSDataTransferError::unknown;
}

- (NSDataTransferError) dataTransferBytesProgressWithId:(UInt64)transferId
                                            withTotal:(SInt64*)total
                                         withProgress:(SInt64*)progress {
    return NSDataTransferError::unknown;
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
