/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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
