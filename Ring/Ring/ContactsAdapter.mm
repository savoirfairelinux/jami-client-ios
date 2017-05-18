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

#import "ContactsAdapter.h"

#import "dring/configurationmanager_interface.h"
#import "Utils.h"
#import "Ring-Swift.h"

@implementation ContactsAdapter

using namespace DRing;

/// Static delegate that will receive the propagated daemon events
static id <ContactsAdapterDelegate> _delegate;

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

    confHandlers.insert(exportable_callback<ConfigurationSignal::ContactAdded>([&](const std::string& account_id,
                                                                                   const std::string& uri,
                                                                                   bool confirmed) {
        if (ContactsAdapter.delegate) {
            NSString* contactURI = [NSString stringWithUTF8String:uri.c_str()];
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            [ContactsAdapter.delegate addedContactWithURI:contactURI forAccountId:accountId confirmed:(BOOL)confirmed];
        }
    }));
}
#pragma mark -

- (void)addContactWithURI:(NSString*)uri withAccountId:(NSString*)accountId{
    addContact(std::string([uri UTF8String]), std::string([accountId UTF8String]));
}

- (NSArray<NSDictionary<NSString*,NSString*>*>*)contactsWithAccountId:(NSString*)accountId {
    return [Utils vectorOfMapsToArray:getContacts(std::string([accountId UTF8String]))];
}

#pragma mark ContactsAdapterDelegate
+ (id <ContactsAdapterDelegate>)delegate {
    return _delegate;
}

+ (void) setDelegate:(id<ContactsAdapterDelegate>)delegate {
    _delegate = delegate;
}
#pragma mark -

@end
