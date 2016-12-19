/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
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

#import <Foundation/Foundation.h>

#import "DaemonThreadManager.h"

@interface DaemonThreadManager ()

@property (readwrite, strong, nonatomic) NSThread *daemonThread;
@property (readwrite, strong, nonatomic) NSOperationQueue *operationQueue;

@end

@implementation DaemonThreadManager

#pragma mark Singleton Methods
+ (instancetype)sharedManager {
    static DaemonThreadManager* sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}
#pragma mark -

- (NSThread *) daemonThread {
    if (!_daemonThread) {
        _daemonThread = [[NSThread alloc] initWithTarget:self
                                                selector:@selector(threadMain:)
                                                  object:nil];
        [_daemonThread start];
    }
    return _daemonThread;
}

- (void)threadMain:(id)data {
    @autoreleasepool {
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        [runloop addPort:[NSMachPort port]
                 forMode:NSDefaultRunLoopMode];
        [runloop runMode:NSDefaultRunLoopMode
              beforeDate:[NSDate distantFuture]];
    }
}

@end
