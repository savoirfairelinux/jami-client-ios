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

#import <Foundation/Foundation.h>

@protocol PeerServicesAdapterDelegate;

@interface PeerServicesAdapter : NSObject

@property (class, nonatomic, weak) id <PeerServicesAdapterDelegate> delegate;

- (uint32_t)queryPeerServicesWithAccountId:(NSString*)accountId
                                   peerUri:(NSString*)peerUri;

- (NSString*)openServiceTunnelWithAccountId:(NSString*)accountId
                                    peerUri:(NSString*)peerUri
                                   deviceId:(NSString*)deviceId
                                  serviceId:(NSString*)serviceId
                                serviceName:(NSString*)serviceName
                                  localPort:(uint16_t)localPort;

- (BOOL)closeServiceTunnelWithAccountId:(NSString*)accountId
                               tunnelId:(NSString*)tunnelId;

- (NSArray<NSDictionary<NSString*,NSString*>*>*)getActiveTunnelsWithAccountId:(NSString*)accountId;

@end
