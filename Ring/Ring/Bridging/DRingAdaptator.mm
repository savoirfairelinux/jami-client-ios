/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
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
#import "DRingAdaptator.h"
#import "DaemonThreadManager.h"
#import "DRingAdaptator.h"

#import "dring/dring.h"

@implementation DRingAdaptator

- (void)initDaemonWithCallbackBlock:(nullable void (^)(BOOL))callbackBlock {
    if ([NSThread currentThread] != [[DaemonThreadManager sharedManager] daemonThread]) {
        [self performSelector:@selector(initDaemonInternalWithCallbackBlock:)
                     onThread:[[DaemonThreadManager sharedManager] daemonThread]
                   withObject:callbackBlock
                waitUntilDone:YES];
    }
    else {
        [self initDaemonInternalWithCallbackBlock:callbackBlock];
    }
}

- (void)initDaemon {
    if ([NSThread currentThread] != [[DaemonThreadManager sharedManager] daemonThread]) {
        [self performSelector:@selector(initDaemonInternalWithCallbackBlock:)
                     onThread:[[DaemonThreadManager sharedManager] daemonThread]
                   withObject:nil
                waitUntilDone:NO];
    }
    else {
        [self initDaemonInternalWithCallbackBlock:nil];
    }
}

- (void)initDaemonInternalWithCallbackBlock:(nullable void (^)(BOOL))callbackBlock {
    NSLog(@"\n Init : %@", [NSThread currentThread]);
    int flag = DRing::DRING_FLAG_CONSOLE_LOG | DRing::DRING_FLAG_DEBUG;
    BOOL success = DRing::init(static_cast<DRing::InitFlag>(flag));
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate) {
            [self.delegate daemonInitializedWithSuccess:success];
        }
    });
}

- (void)startDaemonWithCallbackBlock:(nullable void (^)(BOOL))callbackBlock {
    if ([NSThread currentThread] != [[DaemonThreadManager sharedManager] daemonThread]) {
        [self performSelector:@selector(startDaemonInternalWithCallbackBlock:)
                     onThread:[[DaemonThreadManager sharedManager] daemonThread]
                   withObject:callbackBlock
                waitUntilDone:NO];
    }
    else {
        [self startDaemonInternalWithCallbackBlock:callbackBlock];
    }
}

- (void)startDaemonInternalWithCallbackBlock:(nullable void (^)(BOOL))callbackBlock {
    NSLog(@"\n Start : %@", [NSThread currentThread]);
    BOOL success = DRing::start();
    if (callbackBlock) {
        callbackBlock(success);
    }
}

- (void)fini {
    DRing::fini();
}

- (void)pollEvents {
    if ([NSThread currentThread] != [[DaemonThreadManager sharedManager] daemonThread]) {
        [self performSelector:@selector(pollEventsInternal)
                     onThread:[[DaemonThreadManager sharedManager] daemonThread]
                   withObject:nil
                waitUntilDone:NO];
    }
    else {
        [self pollEventsInternal];
    }
}

- (void)pollEventsInternal {
    NSLog(@"\n Poll : %@", [NSThread currentThread]);
    DRing::pollEvents();
}

- (NSString*)getVersion {
    return [NSString stringWithUTF8String:DRing::version()];
}

@end
