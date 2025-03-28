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

// Accept call
@property (nonatomic, assign) NSInteger acceptCallWithIdCount;
@property (nonatomic, copy, nullable) NSString *acceptCallWithIdCallId;
@property (nonatomic, copy, nullable) NSString *acceptCallWithIdAccountId;
@property (nonatomic, copy, nullable) NSArray *acceptCallWithIdMediaList;
@property (nonatomic, assign) BOOL acceptCallReturnValue;

// Refuse call
@property (nonatomic, assign) NSInteger refuseCallWithIdCount;
@property (nonatomic, copy, nullable) NSString *refuseCallWithIdCallId;
@property (nonatomic, copy, nullable) NSString *refuseCallWithIdAccountId;
@property (nonatomic, assign) BOOL refuseCallReturnValue;

// Place call
@property (nonatomic, assign) NSInteger placeCallWithAccountIdCount;
@property (nonatomic, copy, nullable) NSString *placeCallWithAccountIdAccountId;
@property (nonatomic, copy, nullable) NSString *placeCallWithAccountIdToParticipantId;
@property (nonatomic, copy, nullable) NSArray *placeCallWithAccountIdMediaList;
@property (nonatomic, copy, nullable) NSString *placeCallReturnValue;

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

// Conference management related properties
@property (nonatomic, assign) NSInteger getConferenceCallsCallCount;
@property (nonatomic, copy, nullable) NSString *getConferenceCallsConferenceId;
@property (nonatomic, copy, nullable) NSString *getConferenceCallsAccountId;
@property (nonatomic, copy, nullable) NSArray<NSString*> *getConferenceCallsReturnValue;

@property (nonatomic, assign) NSInteger getConferenceInfoCallCount;
@property (nonatomic, copy, nullable) NSString *getConferenceInfoConferenceId;
@property (nonatomic, copy, nullable) NSString *getConferenceInfoAccountId;
@property (nonatomic, copy, nullable) NSArray<NSDictionary<NSString*, NSString*>*> *getConferenceInfoReturnValue;

@property (nonatomic, assign) NSInteger getConferenceDetailsCallCount;
@property (nonatomic, copy, nullable) NSString *getConferenceDetailsConferenceId;
@property (nonatomic, copy, nullable) NSString *getConferenceDetailsAccountId;
@property (nonatomic, copy, nullable) NSDictionary<NSString*, NSString*> *getConferenceDetailsReturnValue;

@property (nonatomic, assign) NSInteger joinConferenceCallCount;
@property (nonatomic, copy, nullable) NSString *joinConferenceConferenceId;
@property (nonatomic, copy, nullable) NSString *joinConferenceCallId;
@property (nonatomic, copy, nullable) NSString *joinConferenceAccountId;
@property (nonatomic, copy, nullable) NSString *joinConferenceAccount2Id;

@property (nonatomic, assign) NSInteger joinConferencesCallCount;
@property (nonatomic, copy, nullable) NSString *joinConferencesConferenceId;
@property (nonatomic, copy, nullable) NSString *joinConferencesSecondConferenceId;
@property (nonatomic, copy, nullable) NSString *joinConferencesAccountId;
@property (nonatomic, copy, nullable) NSString *joinConferencesAccount2Id;

@property (nonatomic, assign) NSInteger joinCallCallCount;
@property (nonatomic, copy, nullable) NSString *joinCallFirstCallId;
@property (nonatomic, copy, nullable) NSString *joinCallSecondCallId;
@property (nonatomic, copy, nullable) NSString *joinCallAccountId;
@property (nonatomic, copy, nullable) NSString *joinCallAccount2Id;

@property (nonatomic, assign) NSInteger hangUpCallCallCount;
@property (nonatomic, copy, nullable) NSString *hangUpCallCallId;
@property (nonatomic, copy, nullable) NSString *hangUpCallAccountId;
@property (nonatomic, assign) BOOL hangUpCallReturnValue;

@property (nonatomic, assign) NSInteger hangUpConferenceCallCount;
@property (nonatomic, copy, nullable) NSString *hangUpConferenceCallId;
@property (nonatomic, copy, nullable) NSString *hangUpConferenceAccountId;
@property (nonatomic, assign) BOOL hangUpConferenceReturnValue;

@property (nonatomic, assign) NSInteger setActiveParticipantCallCount;
@property (nonatomic, copy, nullable) NSString *setActiveParticipantJamiId;
@property (nonatomic, copy, nullable) NSString *setActiveParticipantConferenceId;
@property (nonatomic, copy, nullable) NSString *setActiveParticipantAccountId;

@property (nonatomic, assign) NSInteger setConferenceLayoutCallCount;
@property (nonatomic, assign) int setConferenceLayoutLayout;
@property (nonatomic, copy, nullable) NSString *setConferenceLayoutConferenceId;
@property (nonatomic, copy, nullable) NSString *setConferenceLayoutAccountId;

@property (nonatomic, assign) NSInteger setConferenceModeratorCallCount;
@property (nonatomic, copy, nullable) NSString *setConferenceModeratorParticipantId;
@property (nonatomic, copy, nullable) NSString *setConferenceModeratorConferenceId;
@property (nonatomic, copy, nullable) NSString *setConferenceModeratorAccountId;
@property (nonatomic, assign) BOOL setConferenceModeratorActive;

@property (nonatomic, assign) NSInteger hangupConferenceParticipantCallCount;
@property (nonatomic, copy, nullable) NSString *hangupConferenceParticipantParticipantId;
@property (nonatomic, copy, nullable) NSString *hangupConferenceParticipantConferenceId;
@property (nonatomic, copy, nullable) NSString *hangupConferenceParticipantAccountId;
@property (nonatomic, copy, nullable) NSString *hangupConferenceParticipantDeviceId;

@property (nonatomic, assign) NSInteger muteStreamCallCount;
@property (nonatomic, copy, nullable) NSString *muteStreamParticipantId;
@property (nonatomic, copy, nullable) NSString *muteStreamConferenceId;
@property (nonatomic, copy, nullable) NSString *muteStreamAccountId;
@property (nonatomic, copy, nullable) NSString *muteStreamDeviceId;
@property (nonatomic, copy, nullable) NSString *muteStreamStreamId;
@property (nonatomic, assign) BOOL muteStreamState;

@property (nonatomic, assign) NSInteger raiseHandCallCount;
@property (nonatomic, copy, nullable) NSString *raiseHandParticipantId;
@property (nonatomic, copy, nullable) NSString *raiseHandConferenceId;
@property (nonatomic, copy, nullable) NSString *raiseHandAccountId;
@property (nonatomic, copy, nullable) NSString *raiseHandDeviceId;
@property (nonatomic, assign) BOOL raiseHandState;

// Method declarations for Conference Management
- (NSArray<NSString*>*)getConferenceCalls:(NSString*)conferenceId accountId:(NSString*)accountId;
- (NSArray*)getConferenceInfo:(NSString*)conferenceId accountId:(NSString*)accountId;
- (NSDictionary<NSString*, NSString*>*)getConferenceDetails:(NSString*)conferenceId accountId:(NSString*)accountId;
- (BOOL)joinConference:(NSString*)confID call:(NSString*)callID accountId:(NSString*)accountId account2Id:(NSString*)account2Id;
- (BOOL)joinConferences:(NSString*)firstConf secondConference:(NSString*)secondConf accountId:(NSString*)accountId account2Id:(NSString*)account2Id;
- (BOOL)joinCall:(NSString*)firstCall second:(NSString*)secondCall accountId:(NSString*)accountId account2Id:(NSString*)account2Id;
- (BOOL)hangUpCall:(NSString*)callId accountId:(NSString*)accountId;
- (BOOL)hangUpConference:(NSString*)conferenceId accountId:(NSString*)accountId;
- (void)setActiveParticipant:(NSString*)callId forConference:(NSString*)conferenceId accountId:(NSString*)accountId;
- (void)setConferenceLayout:(int)layout forConference:(NSString*)conferenceId accountId:(NSString*)accountId;

// Method declarations for Participant Management
- (void)setConferenceModerator:(NSString*)participantId forConference:(NSString*)conferenceId accountId:(NSString*)accountId active:(BOOL)isActive;
- (void)hangupConferenceParticipant:(NSString*)participantId forConference:(NSString*)conferenceId accountId:(NSString*)accountId deviceId:(NSString*)deviceId;
-(void)muteStream:(NSString*)participantId
    forConference:(NSString*)conferenceId
        accountId:(NSString*)accountId
         deviceId:(NSString*)deviceId
         streamId:(NSString*)streamId
            state:(BOOL)state;
-(void)raiseHand:(NSString*)participantId
   forConference:(NSString*)conferenceId
       accountId:(NSString*)accountId
        deviceId:(NSString*)deviceId
           state:(BOOL)state;

@end

NS_ASSUME_NONNULL_END 
