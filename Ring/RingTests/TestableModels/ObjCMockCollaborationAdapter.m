/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

#import "ObjCMockCollaborationAdapter.h"

@implementation ObjCMockCollaborationAdapter

- (instancetype)init {
    self = [super init];
    if (self) {
        _documentsReturnValue = @[];
        _openDocumentReturnValue = [NSData data];
    }
    return self;
}

/// The initializer sends this to itself, so overriding it is enough to keep the
/// daemon out of a test.
- (void)registerConfigurationHandler {
}

- (NSArray<NSDictionary<NSString*, NSString*>*>*)documentsForAccount:(NSString*)accountId
                                                      conversationId:(NSString*)conversationId {
    return self.documentsReturnValue;
}

- (NSData*)openDocumentForAccount:(NSString*)accountId
                   conversationId:(NSString*)conversationId
                       documentId:(NSString*)documentId {
    return self.openDocumentReturnValue;
}

- (void)closeDocumentForAccount:(NSString*)accountId
                 conversationId:(NSString*)conversationId
                     documentId:(NSString*)documentId {
}

@end
