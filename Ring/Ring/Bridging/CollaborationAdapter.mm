/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

#import "CollaborationAdapter.h"

#import "Ring-Swift.h"
#import "Utils.h"
#import "jami/configurationmanager_interface.h"
#import "jami/conversation_interface.h"

@implementation CollaborationAdapter

using namespace libjami;

// __weak, as the property says: a plain static would be a strong reference under
// ARC and would keep the service alive for the lifetime of the process.
static __weak id <CollaborationAdapterDelegate> _delegate;

#pragma mark Init

- (id)init {
    if (self = [super init]) {
        [self registerConfigurationHandler];
    }
    return self;
}

#pragma mark Callbacks registration

- (void)registerConfigurationHandler {
    std::map<std::string, std::shared_ptr<CallbackWrapperBase>> confHandlers;

    confHandlers.insert(exportable_callback<ConfigurationSignal::CollaborativeDocumentUpdate>(
        [&](const std::string& accountId,
            const std::string& conversationId,
            const std::string& documentId,
            const std::vector<uint8_t>& update) {
            // One strong read: a weak delegate can be released between a test and
            // the message that follows it.
            id <CollaborationAdapterDelegate> delegate = CollaborationAdapter.delegate;
            if (!delegate) {
                return;
            }
            [delegate documentUpdateWithAccountId:@(accountId.c_str())
                                   conversationId:@(conversationId.c_str())
                                       documentId:@(documentId.c_str())
                                           update:[Utils dataFromVectorOfUInt8:update]];
        }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::CollaborativeAwarenessChanged>(
        [&](const std::string& accountId,
            const std::string& conversationId,
            const std::string& documentId,
            const std::string& peerId,
            uint64_t clientId,
            const std::string& state) {
            id <CollaborationAdapterDelegate> delegate = CollaborationAdapter.delegate;
            if (!delegate) {
                return;
            }
            [delegate awarenessChangedWithAccountId:@(accountId.c_str())
                                     conversationId:@(conversationId.c_str())
                                         documentId:@(documentId.c_str())
                                             peerId:@(peerId.c_str())
                                           clientId:clientId
                                              state:@(state.c_str())];
        }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::CollaborativeParticipantLeft>(
        [&](const std::string& accountId,
            const std::string& conversationId,
            const std::string& documentId,
            const std::string& peerId,
            uint64_t clientId) {
            id <CollaborationAdapterDelegate> delegate = CollaborationAdapter.delegate;
            if (!delegate) {
                return;
            }
            [delegate participantLeftWithAccountId:@(accountId.c_str())
                                    conversationId:@(conversationId.c_str())
                                        documentId:@(documentId.c_str())
                                            peerId:@(peerId.c_str())
                                          clientId:clientId];
        }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::CollaborativeDocumentRenamed>(
        [&](const std::string& accountId,
            const std::string& conversationId,
            const std::string& documentId,
            const std::string& name) {
            id <CollaborationAdapterDelegate> delegate = CollaborationAdapter.delegate;
            if (!delegate) {
                return;
            }
            [delegate documentRenamedWithAccountId:@(accountId.c_str())
                                    conversationId:@(conversationId.c_str())
                                        documentId:@(documentId.c_str())
                                              name:@(name.c_str())];
        }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::CollaborativeAttachmentAdded>(
        [&](const std::string& accountId,
            const std::string& conversationId,
            const std::string& documentId,
            const std::string& attachmentId) {
            id <CollaborationAdapterDelegate> delegate = CollaborationAdapter.delegate;
            if (!delegate) {
                return;
            }
            [delegate attachmentAddedWithAccountId:@(accountId.c_str())
                                    conversationId:@(conversationId.c_str())
                                        documentId:@(documentId.c_str())
                                      attachmentId:@(attachmentId.c_str())];
        }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::CollaborativeDocumentRemoved>(
        [&](const std::string& accountId,
            const std::string& conversationId,
            const std::string& documentId,
            bool everywhere) {
            id <CollaborationAdapterDelegate> delegate = CollaborationAdapter.delegate;
            if (!delegate) {
                return;
            }
            [delegate documentRemovedWithAccountId:@(accountId.c_str())
                                    conversationId:@(conversationId.c_str())
                                        documentId:@(documentId.c_str())
                                        everywhere:everywhere];
        }));

    registerSignalHandlers(confHandlers);
}

#pragma mark Delegate

+ (id <CollaborationAdapterDelegate>)delegate {
    return _delegate;
}

+ (void)setDelegate:(id <CollaborationAdapterDelegate>)delegate {
    _delegate = delegate;
}

#pragma mark Documents

- (NSString*)createDocumentForAccount:(NSString*)accountId
                       conversationId:(NSString*)conversationId
                                 name:(NSString*)name
                             mimeType:(NSString*)mimeType {
    return @(createCollaborativeDocument(std::string([accountId UTF8String]),
                                         std::string([conversationId UTF8String]),
                                         std::string([name UTF8String]),
                                         std::string([mimeType UTF8String]))
                 .c_str());
}

- (NSData*)openDocumentForAccount:(NSString*)accountId
                   conversationId:(NSString*)conversationId
                       documentId:(NSString*)documentId {
    return [Utils dataFromVectorOfUInt8:openCollaborativeDocument(
                                            std::string([accountId UTF8String]),
                                            std::string([conversationId UTF8String]),
                                            std::string([documentId UTF8String]))];
}

- (void)closeDocumentForAccount:(NSString*)accountId
                 conversationId:(NSString*)conversationId
                     documentId:(NSString*)documentId {
    closeCollaborativeDocument(std::string([accountId UTF8String]),
                               std::string([conversationId UTF8String]),
                               std::string([documentId UTF8String]));
}

- (BOOL)removeDocumentForAccount:(NSString*)accountId
                  conversationId:(NSString*)conversationId
                      documentId:(NSString*)documentId {
    return removeCollaborativeDocument(std::string([accountId UTF8String]),
                                       std::string([conversationId UTF8String]),
                                       std::string([documentId UTF8String]));
}

- (BOOL)removeDocumentLocallyForAccount:(NSString*)accountId
                         conversationId:(NSString*)conversationId
                             documentId:(NSString*)documentId {
    return removeCollaborativeDocumentLocally(std::string([accountId UTF8String]),
                                              std::string([conversationId UTF8String]),
                                              std::string([documentId UTF8String]));
}

- (void)applyUpdateForAccount:(NSString*)accountId
               conversationId:(NSString*)conversationId
                   documentId:(NSString*)documentId
                       update:(NSData*)update {
    applyCollaborativeUpdate(std::string([accountId UTF8String]),
                             std::string([conversationId UTF8String]),
                             std::string([documentId UTF8String]),
                             [Utils vectorOfUInt8FromData:update]);
}

- (NSData*)documentStateForAccount:(NSString*)accountId
                    conversationId:(NSString*)conversationId
                        documentId:(NSString*)documentId {
    return [Utils dataFromVectorOfUInt8:collaborativeDocumentState(
                                            std::string([accountId UTF8String]),
                                            std::string([conversationId UTF8String]),
                                            std::string([documentId UTF8String]))];
}

- (NSData*)documentStateForAccount:(NSString*)accountId
                    conversationId:(NSString*)conversationId
                        documentId:(NSString*)documentId
                          atCommit:(NSString*)commitId {
    return [Utils dataFromVectorOfUInt8:collaborativeDocumentStateAt(
                                            std::string([accountId UTF8String]),
                                            std::string([conversationId UTF8String]),
                                            std::string([documentId UTF8String]),
                                            std::string([commitId UTF8String]))];
}

- (void)setAwarenessForAccount:(NSString*)accountId
                conversationId:(NSString*)conversationId
                    documentId:(NSString*)documentId
                         state:(NSString*)state {
    setCollaborativeAwareness(std::string([accountId UTF8String]),
                              std::string([conversationId UTF8String]),
                              std::string([documentId UTF8String]),
                              std::string([state UTF8String]));
}

- (void)setDocumentNameForAccount:(NSString*)accountId
                   conversationId:(NSString*)conversationId
                       documentId:(NSString*)documentId
                             name:(NSString*)name {
    setCollaborativeDocumentName(std::string([accountId UTF8String]),
                                 std::string([conversationId UTF8String]),
                                 std::string([documentId UTF8String]),
                                 std::string([name UTF8String]));
}

- (NSString*)documentNameForAccount:(NSString*)accountId
                     conversationId:(NSString*)conversationId
                         documentId:(NSString*)documentId {
    return @(collaborativeDocumentName(std::string([accountId UTF8String]),
                                       std::string([conversationId UTF8String]),
                                       std::string([documentId UTF8String]))
                 .c_str());
}

- (NSArray<NSDictionary<NSString*, NSString*>*>*)documentsForAccount:(NSString*)accountId
                                                      conversationId:(NSString*)conversationId {
    return [Utils vectorOfMapsToArray:getCollaborativeDocuments(
                                          std::string([accountId UTF8String]),
                                          std::string([conversationId UTF8String]))];
}

- (NSArray<NSDictionary<NSString*, NSString*>*>*)documentHistoryForAccount:(NSString*)accountId
                                                            conversationId:(NSString*)conversationId
                                                                documentId:(NSString*)documentId
                                                                       max:(uint32_t)max {
    return [Utils vectorOfMapsToArray:getCollaborativeDocumentHistory(
                                          std::string([accountId UTF8String]),
                                          std::string([conversationId UTF8String]),
                                          std::string([documentId UTF8String]),
                                          max)];
}

#pragma mark Attachments

- (NSString*)addAttachmentForAccount:(NSString*)accountId
                      conversationId:(NSString*)conversationId
                          documentId:(NSString*)documentId
                                data:(NSData*)data {
    return @(addCollaborativeAttachment(std::string([accountId UTF8String]),
                                        std::string([conversationId UTF8String]),
                                        std::string([documentId UTF8String]),
                                        [Utils vectorOfUInt8FromData:data])
                 .c_str());
}

- (NSData*)attachmentForAccount:(NSString*)accountId
                 conversationId:(NSString*)conversationId
                     documentId:(NSString*)documentId
                   attachmentId:(NSString*)attachmentId {
    return [Utils dataFromVectorOfUInt8:collaborativeAttachment(
                                            std::string([accountId UTF8String]),
                                            std::string([conversationId UTF8String]),
                                            std::string([documentId UTF8String]),
                                            std::string([attachmentId UTF8String]))];
}

@end
