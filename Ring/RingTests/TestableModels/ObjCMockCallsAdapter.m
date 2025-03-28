/*
 *  Copyright (C) 2025-2025 Savoir-faire Linux Inc.
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

#import "ObjCMockCallsAdapter.h"

@implementation ObjCMockCallsAdapter

- (nullable NSDictionary<NSString *, NSString *> *)callDetailsWithCallId:(NSString *)callId accountId:(NSString *)accountId {
    self.callDetailsCallCount++;
    self.callDetailsCallId = callId;
    self.callDetailsAccountId = accountId;
    return self.callDetailsReturnValue;
}

- (nullable NSArray<NSDictionary<NSString *, NSString *> *> *)currentMediaListWithCallId:(NSString *)callId accountId:(NSString *)accountId {
    self.currentMediaListCallCount++;
    self.currentMediaListCallId = callId;
    self.currentMediaListAccountId = accountId;
    return self.currentMediaListReturnValue;
}

- (void)answerMediaChangeResquest:(NSString *)callId accountId:(NSString *)accountId withMedia:(NSArray *)mediaList {
    self.answerMediaChangeResquestCallCount++;
    self.answerMediaChangeResquestCallId = callId;
    self.answerMediaChangeResquestAccountId = accountId;
    self.answerMediaChangeResquestMedia = mediaList;
}

@end 
