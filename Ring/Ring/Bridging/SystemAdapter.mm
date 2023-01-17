/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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

#import "Ring-Swift.h"

#import "SystemAdapter.h"

#import "jami/configurationmanager_interface.h"

#import "Utils.h"

@implementation SystemAdapter

static id <SystemAdapterDelegate> _delegate;

#pragma mark Init

- (id)init {
    if (self = [super init]) {
        [self registerConfigurationHandler];
    }
    return self;
}

using namespace libjami;

#pragma mark Callbacks registration
- (void)registerConfigurationHandler
{
    std::map<std::string, std::shared_ptr<CallbackWrapperBase>> confHandlers;
    confHandlers.insert(exportable_callback<ConfigurationSignal::GetAppDataPath>(
        [&](const std::string& name, std::vector<std::string>* ret) {
            if (name == "cache") {
                auto path = [Constants cachesPath];
                ret->push_back(std::string([path.path UTF8String]));
            } else {
                auto path = [Constants documentsPath];
                ret->push_back(std::string([path.path UTF8String]));
            }
        }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::MessageSend>(
       [&](const std::string& message) {
           NSString* messageStr = [NSString stringWithUTF8String:message.c_str()];
           [SystemAdapter.delegate messageReceivedWithMessage: messageStr];

    }));

    registerSignalHandlers(confHandlers);
}

#pragma mark -

-(void)triggerLog:(BOOL)trigger {
    monitor(trigger);
}

#pragma mark SystemAdapterDelegate
+ (id <SystemAdapterDelegate>)delegate {
    return _delegate;
}

+ (void) setDelegate:(id<SystemAdapterDelegate>)delegate {
    _delegate = delegate;
}

@end
