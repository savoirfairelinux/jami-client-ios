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

#import <Foundation/Foundation.h>
#import "CallsAdapter.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Objective-C implementation of a mock calls adapter for testing
 */
@interface ObjCMockCallsAdapter : CallsAdapter

// Call details
@property (nonatomic, assign) NSInteger callDetailsCallCount;
@property (nonatomic, copy, nullable) NSString *callDetailsCallId;
@property (nonatomic, copy, nullable) NSString *callDetailsAccountId;
@property (nonatomic, copy, nullable) NSDictionary<NSString*, NSString*> *callDetailsReturnValue;

// Current media list
@property (nonatomic, assign) NSInteger currentMediaListCallCount;
@property (nonatomic, copy, nullable) NSString *currentMediaListCallId;
@property (nonatomic, copy, nullable) NSString *currentMediaListAccountId;
@property (nonatomic, copy, nullable) NSArray<NSDictionary<NSString*, NSString*>*> *currentMediaListReturnValue;

// Answer media change request
@property (nonatomic, assign) NSInteger answerMediaChangeResquestCallCount;
@property (nonatomic, copy, nullable) NSString *answerMediaChangeResquestCallId;
@property (nonatomic, copy, nullable) NSString *answerMediaChangeResquestAccountId;
@property (nonatomic, copy, nullable) NSArray<NSDictionary<NSString*, NSString*>*> *answerMediaChangeResquestMedia;

// For sendTextMessage
@property (nonatomic, assign) BOOL sendTextMessageCalled;
@property (nonatomic, copy, nullable) NSString *sentTextMessageCallId;
@property (nonatomic, copy, nullable) NSString *sentTextMessageAccountId;
@property (nonatomic, copy, nullable) NSDictionary *sentTextMessageMessage;
@property (nonatomic, copy, nullable) NSString *sentTextMessageFrom;
@property (nonatomic, assign) BOOL sentTextMessageIsMixed;

@end

NS_ASSUME_NONNULL_END 
