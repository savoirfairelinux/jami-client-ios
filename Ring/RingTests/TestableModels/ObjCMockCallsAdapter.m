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

- (void)sendTextMessageWithCallID:(NSString*)callId accountId:(NSString*)accountId message:(NSDictionary*)message from:(NSString*)jamiId isMixed:(bool)isMixed {
    self.sendTextMessageCalled = YES;
    self.sentTextMessageCallId = callId;
    self.sentTextMessageAccountId = accountId;
    self.sentTextMessageMessage = message;
    self.sentTextMessageFrom = jamiId;
    self.sentTextMessageIsMixed = isMixed;
}

// Conference Management Method Implementations
- (NSArray<NSString*>*)getConferenceCalls:(NSString*)conferenceId accountId:(NSString*)accountId {
    self.getConferenceCallsCallCount++;
    self.getConferenceCallsConferenceId = conferenceId;
    self.getConferenceCallsAccountId = accountId;
    return self.getConferenceCallsReturnValue ?: @[];
}

- (NSArray*)getConferenceInfo:(NSString*)conferenceId accountId:(NSString*)accountId {
    self.getConferenceInfoCallCount++;
    self.getConferenceInfoConferenceId = conferenceId;
    self.getConferenceInfoAccountId = accountId;
    return self.getConferenceInfoReturnValue ?: @[];
}

- (NSDictionary<NSString*, NSString*>*)getConferenceDetails:(NSString*)conferenceId accountId:(NSString*)accountId {
    self.getConferenceDetailsCallCount++;
    self.getConferenceDetailsConferenceId = conferenceId;
    self.getConferenceDetailsAccountId = accountId;
    return self.getConferenceDetailsReturnValue ?: @{};
}

- (void)joinConference:(NSString*)conferenceId call:(NSString*)callId accountId:(NSString*)accountId account2Id:(NSString*)account2Id {
    self.joinConferenceCallCount++;
    self.joinConferenceConferenceId = conferenceId;
    self.joinConferenceCallId = callId;
    self.joinConferenceAccountId = accountId;
    self.joinConferenceAccount2Id = account2Id;
}

- (void)joinConferences:(NSString*)conferenceId secondConference:(NSString*)secondConferenceId accountId:(NSString*)accountId account2Id:(NSString*)account2Id {
    self.joinConferencesCallCount++;
    self.joinConferencesConferenceId = conferenceId;
    self.joinConferencesSecondConferenceId = secondConferenceId;
    self.joinConferencesAccountId = accountId;
    self.joinConferencesAccount2Id = account2Id;
}

- (void)joinCall:(NSString*)firstCallId second:(NSString*)secondCallId accountId:(NSString*)accountId account2Id:(NSString*)account2Id {
    self.joinCallCallCount++;
    self.joinCallFirstCallId = firstCallId;
    self.joinCallSecondCallId = secondCallId;
    self.joinCallAccountId = accountId;
    self.joinCallAccount2Id = account2Id;
}

- (BOOL)hangUpCall:(NSString*)callId accountId:(NSString*)accountId {
    self.hangUpCallCallCount++;
    self.hangUpCallCallId = callId;
    self.hangUpCallAccountId = accountId;
    return self.hangUpCallReturnValue;
}

- (BOOL)hangUpConference:(NSString*)callId accountId:(NSString*)accountId {
    self.hangUpConferenceCallCount++;
    self.hangUpConferenceCallId = callId;
    self.hangUpConferenceAccountId = accountId;
    return self.hangUpConferenceReturnValue;
}

- (void)setActiveParticipant:(NSString*)jamiId forConference:(NSString*)conferenceId accountId:(NSString*)accountId {
    self.setActiveParticipantCallCount++;
    self.setActiveParticipantJamiId = jamiId;
    self.setActiveParticipantConferenceId = conferenceId;
    self.setActiveParticipantAccountId = accountId;
}

- (void)setConferenceLayout:(NSString*)layout forConference:(NSString*)conferenceId accountId:(NSString*)accountId {
    self.setConferenceLayoutCallCount++;
    self.setConferenceLayoutLayout = layout;
    self.setConferenceLayoutConferenceId = conferenceId;
    self.setConferenceLayoutAccountId = accountId;
}

@end
