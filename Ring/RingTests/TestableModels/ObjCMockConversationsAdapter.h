/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#import "ConversationsAdapter.h"

NS_ASSUME_NONNULL_BEGIN

@interface ObjCMockConversationsAdapter : ConversationsAdapter
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *info;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *preferences;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *members;
@end

NS_ASSUME_NONNULL_END
