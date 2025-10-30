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

#import "CallsAdapter.h"
#import "Utils.h"
#import "jami/callmanager_interface.h"
#import "jami/conversation_interface.h"
#import "Ring-Swift.h"
#import <os/log.h>

using namespace libjami;

@implementation CallsAdapter
/// Static delegate that will receive the propagated daemon events
static id <CallsAdapterDelegate> _delegate;

#pragma mark Init

- (id)init {
    if (self = [super init]) {
        [self registerCallHandler];
    }
    return self;
}

#pragma mark -

#pragma mark Callbacks registration

- (void)registerCallHandler {

    std::map<std::string, std::shared_ptr<CallbackWrapperBase>> callHandlers;

    //State changed signal
    callHandlers.insert(exportable_callback<CallSignal::StateChange>([&](const std::string& accountId, const std::string& callId,
                                                                         const std::string& state,
                                                                         int errorCode) {
        if (CallsAdapter.delegate) {
            NSString* callIdString = [NSString stringWithUTF8String:callId.c_str()];
            NSString* stateString = [NSString stringWithUTF8String:state.c_str()];
            [CallsAdapter.delegate didChangeCallStateWithCallId:callIdString
                                                          state:stateString
                                                      accountId:[NSString stringWithUTF8String:accountId.c_str()]
                                                      stateCode:errorCode];
        }
    }));

    //Incoming message signal
    callHandlers.insert(exportable_callback<CallSignal::IncomingMessage>([&](const std::string& accountId,
                                                                             const std::string& callId,
                                                                             const std::string& fromURI,
                                                                             const std::map<std::string,
                                                                             std::string>& message) {

        if (CallsAdapter.delegate) {
            NSString* callIdString = [NSString stringWithUTF8String:callId.c_str()];
            NSString* fromURIString = [NSString stringWithUTF8String:fromURI.c_str()];
            NSDictionary* messageDict = [Utils mapToDictionary:message];
            [CallsAdapter.delegate didReceiveMessageWithCallId:callIdString
                                                       fromURI:fromURIString
                                                       message:messageDict];
        }
    }));

    callHandlers.insert(exportable_callback<CallSignal::IncomingCallWithMedia>([&](const std::string& accountId,
                                                                                   const std::string& callId,
                                                                                   const std::string& fromURI,
                                                                                   const std::vector<std::map<std::string, std::string>>& media) {
        if (CallsAdapter.delegate) {
            os_log(OS_LOG_DEFAULT, "incoming call");
            NSString* accountIdString = [NSString stringWithUTF8String:accountId.c_str()];
            NSString* callIdString = [NSString stringWithUTF8String:callId.c_str()];
            NSString* fromURIString = [NSString stringWithUTF8String:fromURI.c_str()];
            NSArray* mediaList = [Utils vectorOfMapsToArray:media];
            [CallsAdapter.delegate receivingCallWithAccountId:accountIdString
                                                       callId:callIdString
                                                      fromURI:fromURIString
                                                    withMedia:mediaList];
        }
    }));

    callHandlers.insert(exportable_callback<CallSignal::MediaNegotiationStatus>([&](const std::string& callId,
                                                                                   const std::string& event,
                                                                                   const std::vector<std::map<std::string, std::string>>& media) {
        if (CallsAdapter.delegate) {
            NSString* eventString = [NSString stringWithUTF8String:event.c_str()];
            NSString* callIdString = [NSString stringWithUTF8String:callId.c_str()];
            NSArray* mediaList = [Utils vectorOfMapsToArray:media];
            [CallsAdapter.delegate didChangeMediaNegotiationStatusWithCallId:callIdString
                                                                       event:eventString
                                                                   withMedia:mediaList];
        }
    }));

    callHandlers.insert(exportable_callback<CallSignal::MediaChangeRequested>([&](const std::string& accountId,
                                                                                   const std::string& callId,
                                                                                   const std::vector<std::map<std::string, std::string>>& media) {
        if (CallsAdapter.delegate) {
            NSString* callIdString = [NSString stringWithUTF8String:callId.c_str()];
            NSString* accountIdString = [NSString stringWithUTF8String:accountId.c_str()];
            NSArray* mediaList = [Utils vectorOfMapsToArray:media];
            [CallsAdapter.delegate didReceiveMediaChangeRequestWithAccountId:accountIdString callId:callIdString withMedia:mediaList];
        }
    }));

    //Peer place call on hold signal
    callHandlers.insert(exportable_callback<CallSignal::PeerHold>([&](const std::string& callId,
                                                                      bool holding) {
        if (CallsAdapter.delegate) {
            NSString* callIdString = [NSString stringWithUTF8String: callId.c_str()];
            [CallsAdapter.delegate callPlacedOnHoldWithCallId:callIdString holding:holding];
        }
    }));

    callHandlers.insert(exportable_callback<CallSignal::VideoMuted>([&](const std::string& callId,
                                                                        bool muted) {
        if (CallsAdapter.delegate) {
            NSString* callIdString = [NSString stringWithUTF8String:callId.c_str()];
            [CallsAdapter.delegate videoMutedWithCall: callIdString mute: muted];
        }
    }));

    callHandlers.insert(exportable_callback<CallSignal::AudioMuted>([&](const std::string& callId,
                                                                        bool muted) {
        if (CallsAdapter.delegate) {
            NSString* callIdString = [NSString stringWithUTF8String:callId.c_str()];
            [CallsAdapter.delegate audioMutedWithCall: callIdString mute: muted];
        }
    }));
    callHandlers.insert(exportable_callback<CallSignal::RemoteRecordingChanged>([&](const std::string& callId,const std::string peerId, bool status){
        if (CallsAdapter.delegate) {
            NSString* callIdString = [NSString stringWithUTF8String:callId.c_str()];
            [CallsAdapter.delegate remoteRecordingChangedWithCall:callIdString record:status];
        }
    }));

    callHandlers.insert(exportable_callback<CallSignal::ConferenceCreated>([&](const std::string& accountId, const std::string& conversationId, const std::string& confId) {
        if (CallsAdapter.delegate) {
            NSString* confIdString = [NSString stringWithUTF8String:confId.c_str()];
            NSString* conversationIdString = [NSString stringWithUTF8String:conversationId.c_str()];
            NSString* accountIdString = [NSString stringWithUTF8String:accountId.c_str()];
            [CallsAdapter.delegate conferenceCreatedWithConferenceId:confIdString conversationId:conversationIdString accountId:accountIdString];
        }
    }));

    callHandlers.insert(exportable_callback<CallSignal::ConferenceChanged>([&](const std::string& accountId, const std::string& confId, const std::string& state) {
        if (CallsAdapter.delegate) {
            NSString* confIdString = [NSString stringWithUTF8String:confId.c_str()];
            NSString* stateString = [NSString stringWithUTF8String:state.c_str()];
            [CallsAdapter.delegate conferenceChangedWithConference: confIdString accountId: [NSString stringWithUTF8String:accountId.c_str()] state: stateString];
        }
    }));

    callHandlers.insert(exportable_callback<CallSignal::ConferenceRemoved>([&](const std::string& accountId, const std::string& confId) {
           if (CallsAdapter.delegate) {
               NSString* confIdString = [NSString stringWithUTF8String:confId.c_str()];
               [CallsAdapter.delegate conferenceRemovedWithConference: confIdString];
           }
       }));
    callHandlers.insert(exportable_callback<CallSignal::OnConferenceInfosUpdated>([&](const std::string& confId, const std::vector<std::map<std::string, std::string>>& info) {
        if (CallsAdapter.delegate) {
            auto infoDictionary = [Utils vectorOfMapsToArray: info];
            NSString* confIdString = [NSString stringWithUTF8String:confId.c_str()];
            [CallsAdapter.delegate conferenceInfoUpdatedWithConference:confIdString info: infoDictionary];
        }
    }));

    registerSignalHandlers(callHandlers);
}

#pragma mark -

- (BOOL)acceptCallWithId:(NSString*)callId accountId:(NSString*)accountId withMedia:(NSArray*)mediaList {
    NSLog(@"acceptCallWithId %@", callId);
    return acceptWithMedia(std::string([accountId UTF8String]), std::string([callId UTF8String]), [Utils dictionaryArrayToMapVector: mediaList]);
}

- (BOOL)declineCallWithId:(NSString*)callId accountId:(NSString*)accountId  {
    return refuse(std::string([accountId UTF8String]), std::string([callId UTF8String]));
}

- (BOOL)hangUpCall:(NSString*)callId accountId:(NSString*)accountId  {
    return hangUp(std::string([accountId UTF8String]), std::string([callId UTF8String]));
}

- (BOOL)holdCallWithId:(NSString*)callId accountId:(NSString*)accountId  {
    return hold(std::string([accountId UTF8String]), std::string([callId UTF8String]));
}

- (BOOL)unholdCallWithId:(NSString*)callId accountId:(NSString*)accountId  {
    return unhold(std::string([accountId UTF8String]), std::string([callId UTF8String]));
}

- (void)playDTMF:(NSString*)code {
    playDTMF(std::string([code UTF8String]));
}

- (void)answerMediaChangeResquest:(NSString*)callId accountId:(NSString*)accountId withMedia: (NSArray*)mediaList {
    answerMediaChangeRequest(std::string([accountId UTF8String]), std::string([callId UTF8String]), [Utils dictionaryArrayToMapVector: mediaList]);
}

- (NSString*)placeCallWithAccountId:(NSString*)accountId toParticipantId:(NSString*)participantId withMedia:(NSArray*)mediaList {
    std::string callId;
    callId = placeCallWithMedia(std::string([accountId UTF8String]), std::string([participantId UTF8String]), [Utils dictionaryArrayToMapVector:mediaList]);
    return [NSString stringWithUTF8String:callId.c_str()];
}

- (NSDictionary<NSString*,NSString*>*)callDetailsWithCallId:(NSString*)callId accountId:(NSString*)accountId {
    std::map<std::string, std::string> callDetails = getCallDetails(std::string([accountId UTF8String]), std::string([callId UTF8String]));
    return [Utils mapToDictionary:callDetails];
}

- (NSArray<NSDictionary<NSString*,NSString*>*>*)getActiveCalls:(NSString*)conversationId accountId:(NSString*)accountId {
    std::vector<std::map<std::string, std::string>> calls = getActiveCalls(std::string([accountId UTF8String]), std::string([conversationId UTF8String]));
    return [Utils vectorOfMapsToArray:calls];
}

- (NSArray<NSDictionary<NSString*,NSString*>*>*)currentMediaListWithCallId:(NSString*)callId accountId:(NSString*)accountId {
    std::vector<std::map<std::string, std::string>> medias = currentMediaList(std::string([accountId UTF8String]), std::string([callId UTF8String]));
    return [Utils vectorOfMapsToArray: medias];
}

-(BOOL)muteLocalMediaWithCallId:(NSString*)callId accountId:(NSString*)accountId mediaType:(NSString*)mediaType mute:(BOOL)mute
{
    return muteLocalMedia(std::string([accountId UTF8String]), std::string([callId UTF8String]), std::string([mediaType UTF8String]), mute);
}

- (NSArray<NSString*>*)callsForAccountId:(NSString*)accountId  {
    std::vector<std::string> calls = getCallList(std::string([accountId UTF8String]));
    return [Utils vectorToArray:calls];
}

- (void)sendTextMessageWithCallID:(NSString*)callId accountId:(NSString*)accountId message:(NSDictionary*)message from:(NSString*)jamiId isMixed:(bool)isMixed {
    sendTextMessage(std::string([accountId UTF8String]), std::string([callId UTF8String]), [Utils dictionaryToMap:message], std::string([jamiId UTF8String]), isMixed);
}

- (BOOL)joinConference:(NSString*)confID call:(NSString*)callID accountId:(NSString*)accountId account2Id:(NSString*)account2Id {
    return addParticipant(std::string([accountId UTF8String]), std::string([callID UTF8String]), std::string([account2Id UTF8String]), std::string([confID UTF8String]));
}

- (BOOL)joinConferences:(NSString*)firstConf secondConference:(NSString*)secondConf accountId:(NSString*)accountId account2Id:(NSString*)account2Id {
    return joinConference(std::string([accountId UTF8String]), std::string([firstConf UTF8String]), std::string([account2Id UTF8String]), std::string([secondConf UTF8String]));
}

- (BOOL)joinCall:(NSString*)firstCall second:(NSString*)secondCall accountId:(NSString*)accountId account2Id:(NSString*)account2Id {
    return joinParticipant(std::string([accountId UTF8String]), std::string([firstCall UTF8String]), std::string([account2Id UTF8String]), std::string([secondCall UTF8String]));
}

- (NSArray*)getConferenceInfo:(NSString*)conferenceId accountId:(NSString*)accountId {
    auto result = getConferenceInfos(std::string([accountId UTF8String]), std::string([conferenceId UTF8String]));
    NSArray* arrayResult = [Utils vectorOfMapsToArray:result];
    return arrayResult;
}

- (NSDictionary<NSString*,NSString*>*)getConferenceDetails:(NSString*)conferenceId accountId:(NSString*)accountId {
    std::map<std::string, std::string> confDetails = getConferenceDetails(std::string([accountId UTF8String]), std::string([conferenceId UTF8String]));
    return [Utils mapToDictionary:confDetails];
}

- (NSArray<NSString*>*)getConferenceCalls:(NSString*)conferenceId accountId:(NSString*)accountId {
    std::vector<std::string> calls = getParticipantList(std::string([accountId UTF8String]), std::string([conferenceId UTF8String]));
    return [Utils vectorToArray:calls];
}

- (BOOL)hangUpConference:(NSString*)conferenceId accountId:(NSString*)accountId {
    return hangUpConference(std::string([accountId UTF8String]), std::string([conferenceId UTF8String]));
}

- (void)setActiveParticipant:(NSString*)callId forConference:(NSString*)conferenceId accountId:(NSString*)accountId {
    setActiveParticipant(std::string([accountId UTF8String]), std::string([conferenceId UTF8String]), std::string([callId UTF8String]));
}

- (void)setConferenceLayout:(int)layout forConference:(NSString*)conferenceId accountId:(NSString*)accountId  {
    setConferenceLayout(std::string([accountId UTF8String]), std::string([conferenceId UTF8String]), layout);
}

- (void)setConferenceModerator:(NSString*)participantId forConference:(NSString*)conferenceId accountId:(NSString*)accountId active:(BOOL)isActive {
    setModerator(std::string([accountId UTF8String]), std::string([conferenceId UTF8String]), std::string([participantId UTF8String]), isActive);
}

- (void)hangupConferenceParticipant:(NSString*)participantId forConference:(NSString*)conferenceId accountId:(NSString*)accountId deviceId:(NSString*)deviceId {
    hangupParticipant(std::string([accountId UTF8String]), std::string([conferenceId UTF8String]), std::string([participantId UTF8String]), std::string([deviceId UTF8String]));
}

-(void)muteStream:(NSString*)participantId
    forConference:(NSString*)conferenceId
        accountId:(NSString*)accountId
         deviceId:(NSString*)deviceId
         streamId:(NSString*)streamId
            state:(BOOL)state {
    muteStream(std::string([accountId UTF8String]),
               std::string([conferenceId UTF8String]),
               std::string([participantId UTF8String]),
               std::string([deviceId UTF8String]),
               std::string([streamId UTF8String]),
               state);
}

-(void)raiseHand:(NSString*)participantId
   forConference:(NSString*)conferenceId
       accountId:(NSString*)accountId
        deviceId:(NSString*)deviceId
           state:(BOOL)state {
    raiseHand(std::string([accountId UTF8String]),
              std::string([conferenceId UTF8String]),
              std::string([participantId UTF8String]),
              std::string([deviceId UTF8String]),
              state);
}

#pragma mark AccountAdapterDelegate

+ (id <CallsAdapterDelegate>)delegate {
    return _delegate;
}

+ (void) setDelegate:(id<CallsAdapterDelegate>)delegate {
    _delegate = delegate;
}

#pragma mark -

@end
