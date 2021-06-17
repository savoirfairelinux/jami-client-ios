/*
 *  Copyright (C) 2021 Savoir-faire Linux Inc.
 *
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

#import "Adapter.h"
#import "jami/jami.h"
#import "jami/configurationmanager_interface.h"
#import "jami/callmanager_interface.h"
#import "jami/conversation_interface.h"
#import "jamiNotificationServiceExtension-Swift.h"
#import "Utils.h"

@implementation Adapter

static id <AdapterDelegate> _delegate;

using namespace DRing;

#pragma mark Init
- (id)init {
    if (self = [super init]) {
        [self registerConfigurationHandler];
    }
    return self;
}
#pragma mark -

#pragma mark Callbacks registration
- (void)registerConfigurationHandler {
    std::map<std::string, std::shared_ptr<CallbackWrapperBase>> confHandlers;
    confHandlers.insert(exportable_callback<ConfigurationSignal::GetAppDataPath>([&](const std::string& name,
                                                                                     std::vector<std::string>* ret) {
        
        if (name == "cache") {
            NSURL *appGroupDirectoryPath = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier: @"group.com.savoirfairelinux.ring"];
            NSURL * groupDocUrl = [appGroupDirectoryPath URLByAppendingPathComponent:@"Cashes"];
            NSString* path = groupDocUrl.path;
            ret->push_back(std::string([path UTF8String]));
        }
        else {
            NSURL *appGroupDirectoryPath = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier: @"group.com.savoirfairelinux.ring"];
            NSURL * groupDocUrl = [appGroupDirectoryPath URLByAppendingPathComponent:@"Documents"];
            NSString* path = groupDocUrl.path;
            ret->push_back(std::string([path UTF8String]));
        }
    }));
    
    confHandlers.insert(exportable_callback<ConversationSignal::MessageReceived>([&](const std::string& accountId, const std::string& conversationId, std::map<std::string, std::string> message) {
        NSLog(@"***message received");
        if (Adapter.delegate) {
            NSString* convId =  [NSString stringWithUTF8String:conversationId.c_str()];
            NSString* account =  [NSString stringWithUTF8String:accountId.c_str()];
            NSMutableDictionary* interaction = [Utils mapToDictionnary: message];
            [Adapter.delegate newInteractionWithConversationId:convId accountId:account message: interaction];
        }
    }));
    
    confHandlers.insert(exportable_callback<ConfigurationSignal::IncomingAccountMessage>([&](const std::string& account_id,
                                                                                             const std::string& message_id,
                                                                                             const std::string& from,
                                                                                             const std::map<std::string,
                                                                                             std::string>& payloads) {
        if (Adapter.delegate) {
            NSDictionary* message = [Utils mapToDictionnary:payloads];
            NSString* fromAccount = [NSString stringWithUTF8String:from.c_str()];
            NSString* toAccountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* messageId = [NSString stringWithUTF8String:message_id.c_str()];
            [Adapter.delegate didReceiveMessage:message from:fromAccount messageId: messageId to:toAccountId];
        }
    }));
    
    //Incoming call signal
    confHandlers.insert(exportable_callback<CallSignal::IncomingCall>([&](const std::string& accountId,
                                                                          const std::string& callId,
                                                                          const std::string& fromURI) {
        if (Adapter.delegate) {
            NSString* accountIdString = [NSString stringWithUTF8String:accountId.c_str()];
            NSString* callIdString = [NSString stringWithUTF8String:callId.c_str()];
            NSString* fromURIString = [NSString stringWithUTF8String:fromURI.c_str()];
            [Adapter.delegate receivingCallWithAccountId:accountIdString
                                                  callId:callIdString
                                                 fromURI:fromURIString];
        }
    }));
    
    registerSignalHandlers(confHandlers);
}


#pragma mark AdapterDelegate
+ (id <AdapterDelegate>)delegate {
    return _delegate;
}

+ (void) setDelegate:(id<AdapterDelegate>)delegate {
    _delegate = delegate;
}

- (BOOL)initDaemon {
    if (![[NSThread currentThread] isMainThread]) {
        __block bool success;
        dispatch_sync(dispatch_get_main_queue(), ^{
            success = [self initDaemonInternal];
        });
        return success;
    }
    else {
        return [self initDaemonInternal];
    }
}

- (BOOL) initDaemonInternal {
    return init(static_cast<DRing::InitFlag>(0));
}

- (BOOL)startDaemon {
    if (![[NSThread currentThread] isMainThread]) {
        __block bool success;
        dispatch_sync(dispatch_get_main_queue(), ^{
            success = [self startDaemonInternal];
        });
        return success;
    }
    else {
        return [self startDaemonInternal];
    }
}

- (BOOL)startDaemonInternal {
    return start();
}

- (void)pushNotificationReceived:(NSString*)from message:(NSDictionary*)data {
    pushNotificationReceived(std::string([from UTF8String]), [Utils dictionnaryToMap:data]);
}

@end
