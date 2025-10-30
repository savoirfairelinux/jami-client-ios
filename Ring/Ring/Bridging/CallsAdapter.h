/*
 * Copyright (C) 2017-2025 Savoir-faire Linux Inc.
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

@protocol CallsAdapterDelegate;

@interface CallsAdapter : NSObject

@property (class, nonatomic, weak) id <CallsAdapterDelegate> delegate;

- (BOOL)acceptCallWithId:(NSString*)callId accountId:(NSString*)accountId withMedia:(NSArray*)mediaList;
- (BOOL)declineCallWithId:(NSString*)callId accountId:(NSString*)accountId;
- (BOOL)endCall:(NSString*)callId accountId:(NSString*)accountId;
- (BOOL)holdCallWithId:(NSString*)callId accountId:(NSString*)accountId;
- (BOOL)resumeCallWithId:(NSString*)callId accountId:(NSString*)accountId;
- (void)playDTMF:(NSString*)code;

- (void)answerMediaChangeResquest:(NSString*)callId accountId:(NSString*)accountId withMedia: (NSArray*)mediaList;

- (NSString*)startCallWithAccountId:(NSString*)accountId toParticipantId:(NSString*)participantId withMedia: (NSArray*)mediaList;
- (NSDictionary<NSString*,NSString*>*)callDetailsWithCallId:(NSString*)callId accountId:(NSString*)accountId;
- (NSArray<NSString*>*)callsForAccountId:(NSString*)accountId;
- (void)sendTextMessageWithCallID:(NSString*)callId accountId:(NSString*)accountId message:(NSDictionary*)message from:(NSString*)jamiId isMixed:(bool)isMixed;
- (BOOL)joinConference:(NSString*)confID call:(NSString*)callID accountId:(NSString*)accountId account2Id:(NSString*)account2Id;
- (BOOL)joinConferences:(NSString*)firstConf secondConference:(NSString*)secondConf accountId:(NSString*)accountId account2Id:(NSString*)account2Id;
- (BOOL)joinCall:(NSString*)firstCall second:(NSString*)secondCall accountId:(NSString*)accountId account2Id:(NSString*)account2Id;
- (NSArray*)getConferenceInfo:(NSString*)conferenceId accountId:(NSString*)accountId;
- (NSDictionary<NSString*,NSString*>*)getConferenceDetails:(NSString*)conferenceId accountId:(NSString*)accountId;
- (NSArray<NSString*>*)getConferenceCalls:(NSString*)conferenceId accountId:(NSString*)accountId;
- (BOOL)disconnectConference:(NSString*)conferenceId accountId:(NSString*)accountId;
- (void)setActiveParticipant:(NSString*)callId forConference:(NSString*)conferenceId accountId:(NSString*)accountId;
- (void)setConferenceLayout:(int)layout forConference:(NSString*)conferenceId accountId:(NSString*)accountId;
- (void)setConferenceModerator:(NSString*)participantId forConference:(NSString*)conferenceId accountId:(NSString*)accountId active:(BOOL)isActive;
- (void)disconnectConferenceParticipant:(NSString*)participantId forConference:(NSString*)conferenceId accountId:(NSString*)accountId deviceId:(NSString*)deviceId;
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

- (NSArray<NSDictionary<NSString*,NSString*>*>*)currentMediaListWithCallId:(NSString*)callId accountId:(NSString*)accountId;

-(BOOL)muteLocalMediaWithCallId:(NSString*)callId accountId:(NSString*)accountId mediaType:(NSString*)mediaType mute:(BOOL)mute;
-(NSArray<NSDictionary<NSString*,NSString*>*>*)getActiveCalls:(NSString*)conversationId accountId:(NSString*)accountId;
@end
