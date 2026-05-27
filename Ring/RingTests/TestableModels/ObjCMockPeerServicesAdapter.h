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
#import "PeerServicesAdapter.h"

NS_ASSUME_NONNULL_BEGIN

@interface ObjCMockPeerServicesAdapter : PeerServicesAdapter

@property (nonatomic, assign) uint32_t queryReturnValue;
@property (nonatomic, copy, nullable) NSString *openTunnelReturnValue;
@property (nonatomic, assign) BOOL closeTunnelReturnValue;
@property (nonatomic, copy, nullable) NSArray<NSDictionary<NSString*,NSString*>*> *activeTunnelsReturnValue;

@property (nonatomic, assign) NSInteger closeServiceTunnelCallCount;
@property (nonatomic, copy, nullable) NSString *lastClosedTunnelId;
@property (nonatomic, assign) NSInteger openServiceTunnelCallCount;

@end

NS_ASSUME_NONNULL_END
