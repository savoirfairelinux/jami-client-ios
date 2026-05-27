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

#import "ObjCMockPeerServicesAdapter.h"

@implementation ObjCMockPeerServicesAdapter

- (instancetype)init {
    self = [super init];
    if (self) {
        _queryReturnValue = 1;
        _openTunnelReturnValue = @"test-tunnel-id";
        _closeTunnelReturnValue = YES;
        _closeServiceTunnelCallCount = 0;
        _openServiceTunnelCallCount = 0;
    }
    return self;
}

- (uint32_t)queryPeerServicesWithAccountId:(NSString*)accountId
                                   peerUri:(NSString*)peerUri {
    if (self.onQueryPeerServices) {
        self.onQueryPeerServices(accountId, peerUri);
    }
    return self.queryReturnValue;
}

- (NSString*)openServiceTunnelWithAccountId:(NSString*)accountId
                                    peerUri:(NSString*)peerUri
                                   deviceId:(NSString*)deviceId
                                  serviceId:(NSString*)serviceId
                                serviceName:(NSString*)serviceName
                                  localPort:(uint16_t)localPort {
    self.openServiceTunnelCallCount++;
    return self.openTunnelReturnValue;
}

- (BOOL)closeServiceTunnelWithAccountId:(NSString*)accountId
                               tunnelId:(NSString*)tunnelId {
    self.closeServiceTunnelCallCount++;
    self.lastClosedTunnelId = tunnelId;
    return self.closeTunnelReturnValue;
}

@end
