/*
 * Copyright (C) 2025-2025 Savoir-faire Linux Inc.
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

#import "ObjCMockCallsAdapter.h"

@implementation ObjCMockCallsAdapter

- (nullable NSDictionary<NSString *, NSString *> *)callDetailsWithCallId:(NSString *)callId accountId:(NSString *)accountId {
    self.callDetailsCallCount++;
    self.callDetailsCallId = callId;
    self.callDetailsAccountId = accountId;
    return self.callDetailsReturnValue;
}

- (BOOL)acceptCallWithId:(NSString *)callId accountId:(NSString *)accountId withMedia:(NSArray *)mediaList {
    self.acceptCallWithIdCount++;
    self.acceptCallWithIdCallId = callId;
    self.acceptCallWithIdAccountId = accountId;
    self.acceptCallWithIdMediaList = mediaList;
    return self.acceptCallReturnValue;
}

- (BOOL)refuseCallWithId:(NSString *)callId accountId:(NSString *)accountId {
    self.refuseCallWithIdCount++;
    self.refuseCallWithIdCallId = callId;
    self.refuseCallWithIdAccountId = accountId;
    return self.refuseCallReturnValue;
}

- (NSString *)placeCallWithAccountId:(NSString *)accountId toParticipantId:(NSString *)participantId withMedia:(NSArray *)mediaList {
    self.placeCallWithAccountIdCount++;
    self.placeCallWithAccountIdAccountId = accountId;
    self.placeCallWithAccountIdToParticipantId = participantId;
    self.placeCallWithAccountIdMediaList = mediaList;
    return self.placeCallReturnValue;
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

- (BOOL)joinConference:(NSString*)confID call:(NSString*)callID accountId:(NSString*)accountId account2Id:(NSString*)account2Id {
    self.joinConferenceCallCount++;
    self.joinConferenceConferenceId = confID;
    self.joinConferenceCallId = callID;
    self.joinConferenceAccountId = accountId;
    self.joinConferenceAccount2Id = account2Id;
    return YES;
}

- (BOOL)joinConferences:(NSString*)firstConf secondConference:(NSString*)secondConf accountId:(NSString*)accountId account2Id:(NSString*)account2Id {
    self.joinConferencesCallCount++;
    self.joinConferencesConferenceId = firstConf;
    self.joinConferencesSecondConferenceId = secondConf;
    self.joinConferencesAccountId = accountId;
    self.joinConferencesAccount2Id = account2Id;
    return YES;
}

- (BOOL)joinCall:(NSString*)firstCall second:(NSString*)secondCall accountId:(NSString*)accountId account2Id:(NSString*)account2Id {
    self.joinCallCallCount++;
    self.joinCallFirstCallId = firstCall;
    self.joinCallSecondCallId = secondCall;
    self.joinCallAccountId = accountId;
    self.joinCallAccount2Id = account2Id;
    return YES;
}

- (BOOL)endCall:(NSString*)callId accountId:(NSString*)accountId {
    self.endCallCallCount++;
    self.endCallCallId = callId;
    self.endCallAccountId = accountId;
    return self.endCallReturnValue;
}

- (BOOL)endConference:(NSString*)conferenceId accountId:(NSString*)accountId {
    self.endConferenceCallCount++;
    self.endConferenceCallId = conferenceId;
    self.endConferenceAccountId = accountId;
    return self.endConferenceReturnValue;
}

- (void)setActiveParticipant:(NSString*)callId forConference:(NSString*)conferenceId accountId:(NSString*)accountId {
    self.setActiveParticipantCallCount++;
    self.setActiveParticipantJamiId = callId;
    self.setActiveParticipantConferenceId = conferenceId;
    self.setActiveParticipantAccountId = accountId;
}

- (void)setConferenceLayout:(int)layout forConference:(NSString*)conferenceId accountId:(NSString*)accountId {
    self.setConferenceLayoutCallCount++;
    self.setConferenceLayoutLayout = layout;
    self.setConferenceLayoutConferenceId = conferenceId;
    self.setConferenceLayoutAccountId = accountId;
}

- (void)setConferenceModerator:(NSString*)participantId forConference:(NSString*)conferenceId accountId:(NSString*)accountId active:(BOOL)isActive {
    self.setConferenceModeratorCallCount++;
    self.setConferenceModeratorParticipantId = participantId;
    self.setConferenceModeratorConferenceId = conferenceId;
    self.setConferenceModeratorAccountId = accountId;
    self.setConferenceModeratorActive = isActive;
}

- (void)endConferenceParticipant:(NSString*)participantId forConference:(NSString*)conferenceId accountId:(NSString*)accountId deviceId:(NSString*)deviceId {
    self.endConferenceParticipantCallCount++;
    self.endConferenceParticipantParticipantId = participantId;
    self.endConferenceParticipantConferenceId = conferenceId;
    self.endConferenceParticipantAccountId = accountId;
    self.endConferenceParticipantDeviceId = deviceId;
}

-(void)muteStream:(NSString*)participantId
    forConference:(NSString*)conferenceId
        accountId:(NSString*)accountId
         deviceId:(NSString*)deviceId
         streamId:(NSString*)streamId
            state:(BOOL)state {
    self.muteStreamCallCount++;
    self.muteStreamParticipantId = participantId;
    self.muteStreamConferenceId = conferenceId;
    self.muteStreamAccountId = accountId;
    self.muteStreamDeviceId = deviceId;
    self.muteStreamStreamId = streamId;
    self.muteStreamState = state;
}

-(void)raiseHand:(NSString*)participantId
   forConference:(NSString*)conferenceId
       accountId:(NSString*)accountId
        deviceId:(NSString*)deviceId
           state:(BOOL)state {
    self.raiseHandCallCount++;
    self.raiseHandParticipantId = participantId;
    self.raiseHandConferenceId = conferenceId;
    self.raiseHandAccountId = accountId;
    self.raiseHandDeviceId = deviceId;
    self.raiseHandState = state;
}

@end
