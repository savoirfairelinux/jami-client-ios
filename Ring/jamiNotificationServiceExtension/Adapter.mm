//
//  Adapter.m
//  jamiNotificationServiceExtension
//
//  Created by kateryna on 2021-06-08.
//  Copyright © 2021 Savoir-faire Linux. All rights reserved.
//

#import "Adapter.h"
#import "dring/dring.h"
#import "dring/configurationmanager_interface.h"
#import "dring/callmanager_interface.h"
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
          //  [Adapter.delegate didReceiveMessage:message from:fromAccount messageId: messageId to:toAccountId];
        }
    }));
    
    //Incoming call signal
    confHandlers.insert(exportable_callback<CallSignal::IncomingCall>([&](const std::string& accountId,
                                                                          const std::string& callId,
                                                                          const std::string& fromURI) {
        if (Adapter.delegate) {
            NSString* accountIdString = [NSString stringWithUTF8String:accountId.c_str()];
            NSString* callIdString = [NSString stringWithUTF8String:callId.c_str()];
            NSString* fromURIString = [NSString stringWithUTF8String:fromURI.c_str()];//   [Adapter.delegate receivingCallWithAccountId:accountIdString
                                                      // callId:callIdString
                                                      //fromURI:fromURIString];
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
