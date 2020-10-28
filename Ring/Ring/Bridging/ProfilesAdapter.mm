/*
*  Copyright (C) 2020 Savoir-faire Linux Inc.
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
                                                                                        const std::string& path) {
           if(ProfilesAdapter.delegate) {
               NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
               NSString* uriString = [NSString stringWithUTF8String:uri.c_str()];
               NSString* pathString = [NSString stringWithUTF8String:path.c_str()];
               [ProfilesAdapter.delegate profileReceivedWithContact:uriString withAccountId:accountId path: pathString];
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
