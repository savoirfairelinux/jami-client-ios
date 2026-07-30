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

#import <Foundation/Foundation.h>

@protocol CollaborationAdapterDelegate;

/**
 * Bridges the daemon's collaborative editing API.
 *
 * The daemon knows nothing of what a document holds: updates and attachments
 * cross this boundary as the bytes the editing engine produced, and awareness
 * as an opaque string the clients agree on between themselves.
 */
@interface CollaborationAdapter : NSObject

@property (class, nonatomic, weak) id <CollaborationAdapterDelegate> delegate;

/// @return the new document's id, empty when it could not be created.
- (NSString*)createDocumentForAccount:(NSString*)accountId
                       conversationId:(NSString*)conversationId
                                 name:(NSString*)name
                             mimeType:(NSString*)mimeType;

/// The whole state as a single update. Never empty unless the account is gone.
- (NSData*)openDocumentForAccount:(NSString*)accountId
                   conversationId:(NSString*)conversationId
                       documentId:(NSString*)documentId;

- (void)closeDocumentForAccount:(NSString*)accountId
                 conversationId:(NSString*)conversationId
                     documentId:(NSString*)documentId;

/**
 * Hand over an update produced by this device's own replica. It is not
 * signalled back, and the call cannot fail: it is no acknowledgement.
 */
- (void)applyUpdateForAccount:(NSString*)accountId
               conversationId:(NSString*)conversationId
                   documentId:(NSString*)documentId
                       update:(NSData*)update;

- (NSData*)documentStateForAccount:(NSString*)accountId
                    conversationId:(NSString*)conversationId
                        documentId:(NSString*)documentId;

/// The state at a past checkpoint. Empty when that checkpoint is unknown here.
- (NSData*)documentStateForAccount:(NSString*)accountId
                    conversationId:(NSString*)conversationId
                        documentId:(NSString*)documentId
                          atCommit:(NSString*)commitId;

// The two selectors below are spelled out for Swift: a `set` prefix makes the
// importer read them as property setters and keep them in one piece, where
// every other method here is split at `For`.
- (void)setAwarenessForAccount:(NSString*)accountId
                conversationId:(NSString*)conversationId
                    documentId:(NSString*)documentId
                         state:(NSString*)state
    NS_SWIFT_NAME(setAwareness(forAccount:conversationId:documentId:state:));

- (void)setDocumentNameForAccount:(NSString*)accountId
                   conversationId:(NSString*)conversationId
                       documentId:(NSString*)documentId
                             name:(NSString*)name
    NS_SWIFT_NAME(setDocumentName(forAccount:conversationId:documentId:name:));

- (NSString*)documentNameForAccount:(NSString*)accountId
                     conversationId:(NSString*)conversationId
                         documentId:(NSString*)documentId;

- (NSArray<NSDictionary<NSString*, NSString*>*>*)documentsForAccount:(NSString*)accountId
                                                      conversationId:(NSString*)conversationId;

/// Checkpoints, newest first. @c max of 0 means no limit.
- (NSArray<NSDictionary<NSString*, NSString*>*>*)documentHistoryForAccount:(NSString*)accountId
                                                            conversationId:(NSString*)conversationId
                                                                documentId:(NSString*)documentId
                                                                       max:(uint32_t)max;

/// @return the attachment id to embed in the document, empty on refusal.
- (NSString*)addAttachmentForAccount:(NSString*)accountId
                      conversationId:(NSString*)conversationId
                          documentId:(NSString*)documentId
                                data:(NSData*)data;

/**
 * @return empty while this replica does not hold the payload yet, which is the
 *         normal state right after a peer referenced it. Wait for
 *         attachmentAdded rather than treat it as an error.
 */
- (NSData*)attachmentForAccount:(NSString*)accountId
                 conversationId:(NSString*)conversationId
                     documentId:(NSString*)documentId
                   attachmentId:(NSString*)attachmentId;

@end
