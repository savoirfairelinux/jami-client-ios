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
#import "CollaborationAdapter.h"

NS_ASSUME_NONNULL_BEGIN

/**
 An adapter that talks to nobody.

 The real one registers the collaboration signal handlers as it is built, which
 tests that only need a complete injection bag have no reason to do.
 */
@interface ObjCMockCollaborationAdapter : CollaborationAdapter

@property (nonatomic, copy) NSArray<NSDictionary<NSString*, NSString*>*>* documentsReturnValue;

@end

NS_ASSUME_NONNULL_END
