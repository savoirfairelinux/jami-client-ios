/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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
#import "Utils.h"
#import "dring/configurationmanager_interface.h"
#import "Ring-Swift.h"

using namespace DRing;

@implementation ContactsAdapter
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

    //Incoming trust request signal
    confHandlers.insert(exportable_callback<ConfigurationSignal::IncomingTrustRequest>([&](const std::string& account_id,
                                                                                           const std::string& from,
                                                                                           const std::vector<uint8_t>& payload,
                                                                                           time_t received) {
        if(ContactsAdapter.delegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* senderAccount = [NSString stringWithUTF8String:from.c_str()];
            NSData* payloadData = [Utils dataFromVectorOfUInt8:payload];
            NSDate* receivedDate = [NSDate dateWithTimeIntervalSince1970:received];

            [ContactsAdapter.delegate incomingTrustRequestReceivedFrom:senderAccount
                                                                    to:accountId
                                                           withPayload:payloadData
                                                          receivedDate:receivedDate];
        }
    }));

    //Contact added signal
    confHandlers.insert(exportable_callback<ConfigurationSignal::ContactAdded>([&](const std::string& account_id,
                                                                                   const std::string& uri,
                                                                                   bool confirmed) {
        if(ContactsAdapter.delegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* uriString = [NSString stringWithUTF8String:uri.c_str()];
            [ContactsAdapter.delegate contactAddedWithContact:uriString withAccountId:accountId confirmed:(BOOL)confirmed];
        }
    }));

    //Contact removed signal
    confHandlers.insert(exportable_callback<ConfigurationSignal::ContactRemoved>([&](const std::string& account_id,
                                                                                     const std::string& uri,
                                                                                     bool banned) {
        if(ContactsAdapter.delegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* uriString = [NSString stringWithUTF8String:uri.c_str()];
            [ContactsAdapter.delegate contactRemovedWithContact:uriString withAccountId:accountId banned:(BOOL)banned];
        }
    }));

    confHandlers.insert(exportable_callback<ConfigurationSignal::ProfileReceived>([&](const std::string& account_id,
                                                                                        const std::string& uri,
                                                                                        const std::string& profile) {
           if(ContactsAdapter.delegate) {
               NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
               NSString* uriString = [NSString stringWithUTF8String:uri.c_str()];
               NSString* message = [NSString stringWithUTF8String:profile.c_str()];
               [ContactsAdapter.delegate profileReceivedWithContact:uriString withAccountId:accountId vCard:message];
//               [ContactsAdapter.delegate contactRemovedWithContact:uriString withAccountId:accountId banned:(BOOL)banned];
           }
       }));


    registerSignalHandlers(confHandlers);
}

#pragma mark -

//Contact Requests
- (NSArray<NSDictionary<NSString*,NSString*>*>*)trustRequestsWithAccountId:(NSString*)accountId {
    std::vector<std::map<std::string,std::string>> trustRequestsVector = getTrustRequests(std::string([accountId UTF8String]));
    NSArray* trustRequests = [Utils vectorOfMapsToArray:trustRequestsVector];
    return trustRequests;
}

- (BOOL)acceptTrustRequestFromContact:(NSString*)ringId withAccountId:(NSString*)accountId {
    return acceptTrustRequest(std::string([accountId UTF8String]), std::string([ringId UTF8String]));
}

- (BOOL)discardTrustRequestFromContact:(NSString*)ringId withAccountId:(NSString*)accountId {
    return discardTrustRequest(std::string([accountId UTF8String]), std::string([ringId UTF8String]));
}

- (void)sendTrustRequestToContact:(NSString*)ringId payload:(NSData*)payloadData withAccountId:(NSString*)accountId {
    std::vector<uint8_t> payload = [Utils vectorOfUInt8FromData:payloadData];
    sendTrustRequest(std::string([accountId UTF8String]), std::string([ringId UTF8String]), payload);
}

//Contacts
- (void)addContactWithURI:(NSString*)uri accountId:(NSString*)accountId {
    addContact(std::string([accountId UTF8String]), std::string([uri UTF8String]));
}

- (void)removeContactWithURI:(NSString*)uri accountId:(NSString*)accountId ban:(BOOL)ban {
    removeContact(std::string([accountId UTF8String]), std::string([uri UTF8String]), (bool)ban);
}

- (NSDictionary*)contactDetailsWithURI:(NSString*)uri accountId:(NSString*)accountId {
    std::map<std::string,std::string> contactDetails = getContactDetails(std::string([accountId UTF8String]), std::string([uri UTF8String]));
    return [Utils mapToDictionnary:contactDetails];
}

- (NSArray<NSDictionary<NSString*,NSString*>*>*)contactsWithAccountId:(NSString*)accountId {
    std::vector<std::map<std::string, std::string>> contacts = getContacts(std::string([accountId UTF8String]));
    return [Utils vectorOfMapsToArray:contacts];
}

#pragma mark AccountAdapterDelegate

+ (id <ContactsAdapterDelegate>)delegate {
    return _delegate;
}

+ (void) setDelegate:(id<ContactsAdapterDelegate>)delegate {
    _delegate = delegate;
}

#pragma mark -

@end
