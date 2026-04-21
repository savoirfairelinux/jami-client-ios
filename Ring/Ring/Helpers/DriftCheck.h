/*
 *  Copyright (C) 2026 Savoir-faire Linux Inc.
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

NS_ASSUME_NONNULL_BEGIN

/// Reads the daemon-produced contacts file via the shared `ContactShallow`
/// struct (same mirror used by the NSE) and verifies that a seeded active/banned
/// contact pair decodes correctly on every field. Returns "PASS" on success or
/// "FAIL: …" on mismatch — the caller delivers it to the UI test.
@interface DriftCheck : NSObject
+ (NSString*)runForAccount:(NSString*)accountId
                     peerA:(NSString*)peerA
                     peerB:(NSString*)peerB;
@end

NS_ASSUME_NONNULL_END
