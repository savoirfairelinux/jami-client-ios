/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

@protocol CallsAdapterDelegate;

@interface CallsAdapter : NSObject

@property (class, nonatomic, weak) id <CallsAdapterDelegate> delegate;

- (BOOL)acceptCallWithId:(NSString*)callId;
- (BOOL)refuseCallWithId:(NSString*)callId;
- (BOOL)hangUpCallWithId:(NSString*)callId;
- (BOOL)holdCallWithId:(NSString*)callId;
- (BOOL)unholdCallWithId:(NSString*)callId;

- (NSString*)placeCallWithAccountId:(NSString*)accountId toRingId:(NSString*)ringId details:(NSDictionary*)details;
- (NSDictionary<NSString*,NSString*>*)callDetailsWithCallId:(NSString*)callId;
- (NSArray<NSString*>*)calls;
- (void) sendTextMessageWithCallID:(NSString*)callId message:(NSDictionary*)message accountId:(NSString*)accountId sMixed:(bool)isMixed;
- (BOOL) muteMedia:(NSString*)callId mediaType:(NSString*)media muted:(bool)muted;
- (void) playDTMF:(NSString*)code;

- (BOOL)joinConference:(NSString*)confID call:(NSString*)callID;
- (BOOL)joinConferences:(NSString*)firstConf secondConference:(NSString*)secondConf;
- (BOOL)joinCall:(NSString*)firstCall second:(NSString*)secondCall;
- (NSDictionary<NSString*,NSString*>*)getConferenceDetails:(NSString*)conferenceId;
- (NSArray<NSString*>*)getConferenceCalls:(NSString*)conferenceId;
- (BOOL)hangUpConference:(NSString*)conferenceId;
- (void)setActiveParticipant:(NSString*)callId forConference:(NSString*)conferenceId;
- (void)setConferenceLayout:(int)layout forConference:(NSString*)conferenceId;
- (NSArray*)getConferenceInfo:(NSString*)conferenceId;
- (void)setConferenceModerator:(NSString*)participantId forConference:(NSString*)conferenceId active:(BOOL)isActive;
- (void)muteConferenceParticipant:(NSString*)participantId forConference:(NSString*)conferenceId active:(BOOL)isActive;
- (void)hangupConferenceParticipant:(NSString*)participantId forConference:(NSString*)conferenceId;
@end
