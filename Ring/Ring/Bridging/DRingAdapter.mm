/*
 *  Copyright (C) 2016-2018 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301
 * USA.
 */

#import "DRingAdapter.h"

#import "Utils.h"
#import "jami/jami.h"
#import "jami/configurationmanager_interface.h"
#if DEBUG_TOOLS_ENABLED
#include "jami/telemetry.h"
#endif

@implementation DRingAdapter

using namespace libjami;

- (BOOL)initDaemon {
    if (![[NSThread currentThread] isMainThread]) {
        __block bool success;
        dispatch_sync(dispatch_get_main_queue(), ^{
            success = [self initDaemonInternal];
        });
        return success;
    }
    else {
        return [self initDaemonInternal];
    }
}

- (BOOL) initDaemonInternal {
#if DEBUG
    int flag = LIBJAMI_FLAG_DEBUG | LIBJAMI_FLAG_CONSOLE_LOG | LIBJAMI_FLAG_SYSLOG;
#else
    int flag = 0;
#endif
#if DEBUG_TOOLS_ENABLED
    setenv("JAMI_LOG_DHT", "1", 1);
#endif
    bool success = init(static_cast<InitFlag>(flag));
#if DEBUG_TOOLS_ENABLED
    if (success) {
        [self initTelemetry];
    }
#endif
    return success;
}

- (BOOL)startDaemon {
    if (![[NSThread currentThread] isMainThread]) {
        __block bool success;
        dispatch_sync(dispatch_get_main_queue(), ^{
            success = [self startDaemonInternal];
        });
        return success;
    }
    else {
        return [self startDaemonInternal];
    }
}

- (BOOL)startDaemonInternal {
    return start();
}

- (void)fini {
#if DEBUG_TOOLS_ENABLED
    [self shutdownTelemetry];
#endif
    if (![[NSThread currentThread] isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            fini();
        });
    }
    else {
        fini();
    }
}

- (void)connectivityChanged {
    if (![[NSThread currentThread] isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            connectivityChanged();
        });
    }
    else {
        connectivityChanged();
    }
}

- (NSString*)getVersion {
    if (![[NSThread currentThread] isMainThread]) {
        __block NSString *version;
        dispatch_sync(dispatch_get_main_queue(), ^{
            version = [NSString stringWithUTF8String:libjami::version()];
        });
        return version;
    }
    else {
        return [NSString stringWithUTF8String:version()];
    }
}

#if DEBUG_TOOLS_ENABLED
- (void)initTelemetry {
    NSString *version = [NSString stringWithUTF8String:libjami::version()];
    jami::telemetry::initTelemetry("jami.ios.daemon", [version UTF8String]);
}

- (void)shutdownTelemetry {
    jami::telemetry::shutdownTelemetry();
}

- (NSString*)drainSpans {
    auto spans = jami::telemetry::drainSpans();
    auto json = jami_ios_telemetry::spansToJson(std::move(spans));
    return [NSString stringWithUTF8String:json.c_str()];
}

- (NSUInteger)spanCount {
    return static_cast<NSUInteger>(jami::telemetry::spanCount());
}
#endif

@end
