/*
 *  Copyright (C) 2021-2022 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

#import "ShareAdapter.h"
#import "ShareUtils.h"
#import "UIKit/UIKit.h"
#import "ShareExtension-Swift.h"

#import "jami/jami.h"

@implementation ShareAdapter

static id<ShareAdapterDelegate> _delegate;

using namespace libjami;

// Constants
const std::string fileSeparator = "/";
NSString* const certificates = @"certificates";
NSString* const crls = @"crls";
NSString* const ocsp = @"ocsp";
NSString* const nameCache = @"namecache";
NSString* const defaultNameServer = @"ns.jami.net";
std::string const nameServerConfiguration = "RingNS.uri";
NSString* const accountConfig = @"config.yml";

std::map<std::string, std::shared_ptr<CallbackWrapperBase>> confHandlers;
std::map<std::string, std::string> cachedNames;
std::map<std::string, std::string> nameServers;

#pragma mark AdapterDelegate
+ (id<ShareAdapterDelegate>)delegate
{
    return _delegate;
}

+ (void)setDelegate:(id<ShareAdapterDelegate>)delegate
{
    _delegate = delegate;
}

- (BOOL)start:(NSString*)accountId
{
    if (initialized() == true) {
        return true;
    }
#if DEBUG
    int flag = LIBJAMI_FLAG_CONSOLE_LOG | LIBJAMI_FLAG_DEBUG | LIBJAMI_FLAG_IOS_EXTENSION | LIBJAMI_FLAG_NO_AUTOSYNC | LIBJAMI_FLAG_NO_LOCAL_AUDIO;
#else
    int flag = LIBJAMI_FLAG_IOS_EXTENSION | LIBJAMI_FLAG_NO_AUTOSYNC | LIBJAMI_FLAG_NO_LOCAL_AUDIO;
#endif
    if (![[NSThread currentThread] isMainThread]) {
        __block bool success;
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (init(static_cast<InitFlag>(flag))) {
                success = start({});
            } else {
                success = false;
            }
        });
        return success;
    } else {
        if (init(static_cast<InitFlag>(flag))) {
            return start({});
        }
        return false;
    }
}

- (void)stop
{
    confHandlers.clear();
}

//-(NSString*)getNameFor:(NSString*)address accountId:(NSString*)accountId {
//    return @(getName(std::string([address UTF8String]), std::string([accountId UTF8String])).c_str());
//}
//
//-(NSString*)nameServerForAccountId:(NSString*)accountId; {
//    auto nameServer = getNameServer(std::string([accountId UTF8String]));
//    return nameServer.empty() ? defaultNameServer : @(nameServer.c_str());
//}

//std::string getName(std::string addres, std::string accountId)
//{
//    auto name = cachedNames.find(addres);
//    if (name != cachedNames.end()) {
//        return name->second;
//    }
//
//    auto ns = getNameServer(accountId);
//    NSURL *url = [NSURL URLWithString: @(ns.c_str())];
//    NSString* host = [url host];
//    NSString* nameServer = host.length == 0 ? defaultNameServer : host;
//    std::string namesPath = [[[Constants cachesPath] URLByAppendingPathComponent: nameCache] URLByAppendingPathComponent: nameServer].path.UTF8String;

//    msgpack::unpacker pac;
//    // read file
//    std::ifstream file = std::ifstream(namesPath, std::ios_base::in);
//    if (!file.is_open()) {
//        return "";
//    }
//    std::string line;
//    while (std::getline(file, line)) {
//        pac.reserve_buffer(line.size());
//        memcpy(pac.buffer(), line.data(), line.size());
//        pac.buffer_consumed(line.size());
//    }
//
//    // load values
//    msgpack::object_handle oh;
//    if (pac.next(oh))
//        oh.get().convert(cachedNames);
//    auto cacheRes = cachedNames.find(addres);
//    return cacheRes != cachedNames.end() ? cacheRes->second : std::string {};
//}

//std::string getNameServer(std::string accountId) {
//    auto it = nameServers.find(accountId);
//    if (it != nameServers.end()) {
//        return it->second;
//    }
//    std::string nameServer {};
//    auto accountConfigPath = [[[Constants documentsPath] URLByAppendingPathComponent: @(accountId.c_str())] URLByAppendingPathComponent: accountConfig].path.UTF8String;
//    try {
//        std::ifstream file = std::ifstream(accountConfigPath, std::ios_base::in);
//        YAML::Node node = YAML::Load(file);
//        file.close();
//        nameServer = node[nameServerConfiguration].as<std::string>();
//        if (!nameServer.empty()) {
//            nameServers.insert(std::pair<std::string, std::string>(accountId, nameServer));
//        }
//    } catch (const std::exception& e) {}
//    return nameServer;
//}
@end
