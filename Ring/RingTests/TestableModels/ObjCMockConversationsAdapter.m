/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#import "ObjCMockConversationsAdapter.h"

@implementation ObjCMockConversationsAdapter

- (void)registerConfigurationHandler {}

- (NSMutableDictionary<NSString *, NSString *> *)getConversationInfoForAccount:(NSString *)accountId
                                                             conversationId:(NSString *)conversationId {
    return [self.info mutableCopy];
}

- (NSMutableDictionary<NSString *, NSString *> *)getConversationPreferencesForAccount:(NSString *)accountId
                                                                    conversationId:(NSString *)conversationId {
    return [self.preferences mutableCopy];
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)getConversationMembers:(NSString *)accountId
                                                          conversationId:(NSString *)conversationId {
    return self.members;
}

- (uint32_t)loadConversationMessages:(NSString *)accountId conversationId:(NSString *)conversationId
                               from:(NSString *)fromMessage size:(NSInteger)size {
    return 0;
}

- (uint32_t)countInteractions:(NSString *)accountId conversationId:(NSString *)conversationId
                        from:(NSString *)messageFrom to:(NSString *)messageTo authorUri:(NSString *)authorUri {
    return 0;
}

@end
