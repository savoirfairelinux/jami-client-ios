/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

#import "PeerServicesAdapter.h"
#import "Utils.h"
#import "jami/networkservice_interface.h"
#import "Ring-Swift.h"

using namespace libjami;

static NSString* safeString(const std::string& s) {
    NSString* str = [NSString stringWithUTF8String:s.c_str()];
    return str ?: @"";
}

@implementation PeerServicesAdapter

static id <PeerServicesAdapterDelegate> _delegate;

#pragma mark Init

- (id)init {
    if (self = [super init]) {
        [self registerServiceHandlers];
    }
    return self;
}

#pragma mark -

#pragma mark Callbacks registration

- (void)registerServiceHandlers {
    std::map<std::string, std::shared_ptr<CallbackWrapperBase>> serviceHandlers;

    serviceHandlers.insert(exportable_callback<ServiceSignal::PeerServicesReceived>(
        [&](uint32_t requestId,
            const std::string& accountId,
            const std::string& peerId,
            int status,
            const std::string& servicesJson) {
            id<PeerServicesAdapterDelegate> delegate = PeerServicesAdapter.delegate;
            if (delegate) {
                [delegate peerServicesReceivedWithRequestId:requestId
                                                 accountId:safeString(accountId)
                                                    peerId:safeString(peerId)
                                                    status:status
                                              servicesJson:safeString(servicesJson)];
            }
        }
    ));

    serviceHandlers.insert(exportable_callback<ServiceSignal::TunnelOpened>(
        [&](const std::string& accountId,
            const std::string& tunnelId,
            uint16_t localPort) {
            id<PeerServicesAdapterDelegate> delegate = PeerServicesAdapter.delegate;
            if (delegate) {
                [delegate serviceTunnelOpenedWithAccountId:safeString(accountId)
                                                 tunnelId:safeString(tunnelId)
                                                localPort:localPort];
            }
        }
    ));

    serviceHandlers.insert(exportable_callback<ServiceSignal::TunnelClosed>(
        [&](const std::string& accountId,
            const std::string& tunnelId,
            const std::string& reason) {
            id<PeerServicesAdapterDelegate> delegate = PeerServicesAdapter.delegate;
            if (delegate) {
                [delegate serviceTunnelClosedWithAccountId:safeString(accountId)
                                                 tunnelId:safeString(tunnelId)
                                                   reason:safeString(reason)];
            }
        }
    ));

    registerSignalHandlers(serviceHandlers);
}

#pragma mark API calls

- (uint32_t)queryPeerServicesWithAccountId:(NSString*)accountId
                                   peerUri:(NSString*)peerUri {
    return queryPeerServices(std::string([accountId UTF8String]),
                             std::string([peerUri UTF8String]));
}

- (NSString*)openServiceTunnelWithAccountId:(NSString*)accountId
                                    peerUri:(NSString*)peerUri
                                   deviceId:(NSString*)deviceId
                                  serviceId:(NSString*)serviceId
                                serviceName:(NSString*)serviceName
                                  localPort:(uint16_t)localPort {
    auto tunnelId = openServiceTunnel(std::string([accountId UTF8String]),
                                      std::string([peerUri UTF8String]),
                                      std::string([deviceId UTF8String]),
                                      std::string([serviceId UTF8String]),
                                      std::string([serviceName UTF8String]),
                                      localPort);
    return safeString(tunnelId);
}

- (BOOL)closeServiceTunnelWithAccountId:(NSString*)accountId
                               tunnelId:(NSString*)tunnelId {
    return closeServiceTunnel(std::string([accountId UTF8String]),
                              std::string([tunnelId UTF8String]));
}

- (NSArray<NSDictionary<NSString*,NSString*>*>*)getActiveTunnelsWithAccountId:(NSString*)accountId {
    return [Utils vectorOfMapsToArray:getActiveTunnels(std::string([accountId UTF8String]))];
}

#pragma mark PeerServicesAdapterDelegate

+ (id <PeerServicesAdapterDelegate>)delegate {
    return _delegate;
}

+ (void)setDelegate:(id<PeerServicesAdapterDelegate>)delegate {
    _delegate = delegate;
}

#pragma mark -

@end
