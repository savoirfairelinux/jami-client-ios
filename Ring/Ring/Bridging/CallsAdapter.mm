/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

#import "CallsAdapter.h"
#import "Utils.h"
#import "dring/callmanager_interface.h"
#import "Ring-Swift.h"

using namespace DRing;

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
    callHandlers.insert(exportable_callback<CallSignal::StateChange>([&](const std::string& callId,
                                                                         const std::string& state,
                                                                         int errorCode) {
        if (CallsAdapter.delegate) {
            NSString* callIdString = [NSString stringWithUTF8String:callId.c_str()];
            NSString* stateString = [NSString stringWithUTF8String:state.c_str()];
            [CallsAdapter.delegate didChangeCallStateWithCallId:callIdString
                                                          state:stateString
                                                      stateCode:errorCode];
        }
    }));

    //Incoming message signal
    callHandlers.insert(exportable_callback<CallSignal::IncomingMessage>([&](const std::string& callId,
                                                                         const std::string& fromURI,
                                                                         const std::map<std::string,
                                                                             std::string>& message) {

        if (CallsAdapter.delegate) {
            NSString* callIdString = [NSString stringWithUTF8String:callId.c_str()];
            NSString* fromURIString = [NSString stringWithUTF8String:fromURI.c_str()];
            NSDictionary* messageDict = [Utils mapToDictionnary:message];
            [CallsAdapter.delegate didReceiveMessageWithCallId:callIdString
                                                       fromURI:fromURIString
                                                       message:messageDict];
        }
    }));

    //Incoming call signal
    callHandlers.insert(exportable_callback<CallSignal::IncomingCall>([&](const std::string& accountId,
                                                                         const std::string& callId,
                                                                         const std::string& fromURI) {
        if (CallsAdapter.delegate) {
            NSString* accountIdString = [NSString stringWithUTF8String:accountId.c_str()];
            NSString* callIdString = [NSString stringWithUTF8String:callId.c_str()];
            NSString* fromURIString = [NSString stringWithUTF8String:fromURI.c_str()];
            [CallsAdapter.delegate receivingCallWithAccountId:accountIdString
                                                       callId:callIdString
                                                      fromURI:fromURIString];
        }
    }));

    registerCallHandlers(callHandlers);
}

#pragma mark -

- (BOOL)acceptCallWithId:(NSString*)callId {
    return accept(std::string([callId UTF8String]));
}

- (BOOL)refuseCallWithId:(NSString*)callId {
    return refuse(std::string([callId UTF8String]));
}

- (BOOL)hangUpCallWithId:(NSString*)callId {
    return hangUp(std::string([callId UTF8String]));
}

- (BOOL)holdCallWithId:(NSString*)callId {
    return hold(std::string([callId UTF8String]));
}

- (BOOL)unholdCallWithId:(NSString*)callId {
    return unhold(std::string([callId UTF8String]));
}

- (NSString*)placeCallWithAccountId:(NSString*)accountId toRingId:(NSString*)ringId {
    std::string callId = placeCall(std::string([accountId UTF8String]), std::string([ringId UTF8String]));
    return [NSString stringWithUTF8String:callId.c_str()];
}

- (NSDictionary<NSString*,NSString*>*)callDetailsWithCallId:(NSString*)callId {
    std::map<std::string, std::string> callDetails = getCallDetails(std::string([callId UTF8String]));
    return [Utils mapToDictionnary:callDetails];
}

- (NSArray<NSString*>*)calls {
    std::vector<std::string> calls = getCallList();
    return [Utils vectorToArray:calls];
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
