/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
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

#import "PresenceAdapter.h"
#import "Utils.h"
#import "jami/presencemanager_interface.h"
#import "Ring-Swift.h"

using namespace libjami;

@implementation PresenceAdapter

// Static delegate that will receive the propagated daemon events
static id <PresenceAdapterDelegate> _delegate;

#pragma mark Init

- (id)init {
    if (self = [super init]) {
        [self registerPresenceHandlers];
    }
    return self;
}

#pragma mark -

#pragma mark Callbacks registration

- (void)registerPresenceHandlers {
    std::map<std::string, std::shared_ptr<CallbackWrapperBase>> presenceHandlers;

    // Incoming buddy notification
    presenceHandlers.insert(exportable_callback<PresenceSignal::NewBuddyNotification>([&](const std::string& account_id,
                                                                                      const std::string& uri,
                                                                                      int status,
                                                                                      const std::string& lineStatus) {
        if(PresenceAdapter.delegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* jamiId = [NSString stringWithUTF8String:uri.c_str()];
            NSString* lineStatusString = [NSString stringWithUTF8String:lineStatus.c_str()];

            [PresenceAdapter.delegate newBuddyNotificationWithAccountId:accountId withJamiId:jamiId withStatus:(NSInteger)status withLineStatus:lineStatusString];
        }
    }));

    registerSignalHandlers(presenceHandlers);
}

#pragma mark -

- (void)subscribeBuddyWithJamiId:(NSString*)jamiId WithAccountId:(NSString*)accountId WithFlag:(BOOL)flag {
    subscribeBuddy(std::string([accountId UTF8String]), std::string([jamiId UTF8String]), (bool)flag);
}

#pragma mark PresenceAdapterDelegate

+ (id <PresenceAdapterDelegate>)delegate {
    return _delegate;
}

+ (void) setDelegate:(id<PresenceAdapterDelegate>)delegate {
    _delegate = delegate;
}

#pragma mark -

@end
