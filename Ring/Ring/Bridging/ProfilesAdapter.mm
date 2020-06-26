//
//  ProfilesAdapter.m
//  Ring
//
//  Created by kateryna on 2020-07-08.
//  Copyright © 2020 Savoir-faire Linux. All rights reserved.
//

#import "ProfilesAdapter.h"
#import "dring/configurationmanager_interface.h"
#import "Ring-Swift.h"

using namespace DRing;

// Static delegate that will receive the propagated daemon events
static id <ProfilesAdapterDelegate> _delegate;

@implementation ProfilesAdapter

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


    confHandlers.insert(exportable_callback<ConfigurationSignal::ProfileReceived>([&](const std::string& account_id,
                                                                                        const std::string& uri,
                                                                                        const std::string& profile) {
           if(ProfilesAdapter.delegate) {
               NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
               NSString* uriString = [NSString stringWithUTF8String:uri.c_str()];
               NSString* profileString = [NSString stringWithUTF8String:profile.c_str()];
               [ProfilesAdapter.delegate profileReceivedWithContact:uriString withAccountId:accountId vCard: profileString];
           }
       }));

    registerSignalHandlers(confHandlers);
}

#pragma mark AccountAdapterDelegate

+ (id <ProfilesAdapterDelegate>)delegate {
    return _delegate;
}

+ (void) setDelegate:(id<ProfilesAdapterDelegate>)delegate {
    _delegate = delegate;
}

@end
