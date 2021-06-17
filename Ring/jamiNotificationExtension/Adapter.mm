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

#import "Adapter.h"
#import "jami/jami.h"
#import "jami/configurationmanager_interface.h"
#import "jami/callmanager_interface.h"
#import "jami/conversation_interface.h"
#import "jamiNotificationExtension-Swift.h"
#import "Utils.h"
#import "opendht/crypto.h"
#import "json/json.h"
#import "opendht/default_types.h"
#import "fstream"
#import "charconv"

@implementation Adapter

static id <AdapterDelegate> _delegate;

using namespace DRing;

struct PeerConnectionRequest : public dht::EncryptedValue<PeerConnectionRequest>
{
    static const constexpr dht::ValueType& TYPE = dht::ValueType::USER_DATA;
    static constexpr const char* key_prefix = "peer:";
    dht::Value::Id id = dht::Value::INVALID_ID;
    std::string ice_msg {};
    bool isAnswer {false};
    bool forceSocket {false};
    MSGPACK_DEFINE_MAP(id, ice_msg, isAnswer, forceSocket)
};

#pragma mark Init
- (id)init {
    if (self = [super init]) {
        [self registerConfigurationHandler];
    }
    return self;
}
#pragma mark -

#pragma mark Callbacks registration
- (void)registerConfigurationHandler {
    std::map<std::string, std::shared_ptr<CallbackWrapperBase>> confHandlers;
    confHandlers.insert(exportable_callback<ConfigurationSignal::GetAppDataPath>([&](const std::string& name,
                                                                                     std::vector<std::string>* ret) {
        
        if (name == "cache") {
            NSURL *appGroupDirectoryPath = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier: @"group.com.savoirfairelinux.ring"];
            NSURL * groupCachesUrl = [[appGroupDirectoryPath URLByAppendingPathComponent:@"Library"] URLByAppendingPathComponent:@"Caches"];
            NSString* path = groupCachesUrl.path;
            ret->push_back(std::string([path UTF8String]));
        }
        else {
            NSURL *appGroupDirectoryPath = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier: @"group.com.savoirfairelinux.ring"];
            NSURL * groupDocUrl = [appGroupDirectoryPath URLByAppendingPathComponent:@"Documents"];
            NSString* path = groupDocUrl.path;
            ret->push_back(std::string([path UTF8String]));
        }
    }));
    
    confHandlers.insert(exportable_callback<ConversationSignal::MessageReceived>([&](const std::string& accountId, const std::string& conversationId, std::map<std::string, std::string> message) {
        if (Adapter.delegate) {
            NSString* convId =  [NSString stringWithUTF8String:conversationId.c_str()];
            NSString* account =  [NSString stringWithUTF8String:accountId.c_str()];
            NSMutableDictionary* interaction = [Utils mapToDictionnary: message];
            [Adapter.delegate newInteractionWithConversationId:convId accountId:account message: interaction];
        }
    }));
    
    confHandlers.insert(exportable_callback<ConfigurationSignal::IncomingAccountMessage>([&](const std::string& account_id,
                                                                                             const std::string& message_id,
                                                                                             const std::string& from,
                                                                                             const std::map<std::string,
                                                                                             std::string>& payloads) {
        if (Adapter.delegate) {
            NSDictionary* message = [Utils mapToDictionnary:payloads];
            NSString* fromAccount = [NSString stringWithUTF8String:from.c_str()];
            NSString* toAccountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* messageId = [NSString stringWithUTF8String:message_id.c_str()];
            [Adapter.delegate didReceiveMessage:message from:fromAccount messageId: messageId to:toAccountId];
        }
    }));
    registerSignalHandlers(confHandlers);
}

#pragma mark AdapterDelegate
+ (id <AdapterDelegate>)delegate {
    return _delegate;
}

+ (void) setDelegate:(id<AdapterDelegate>)delegate {
    _delegate = delegate;
}

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
    return init(static_cast<DRing::InitFlag>(0));
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
    return start({}, true);
}

- (void)pushNotificationReceived:(NSString*)from message:(NSDictionary*)data {
    pushNotificationReceived(std::string([from UTF8String]), [Utils dictionnaryToMap:data]);
}

- (NotificationType)decrypt:(NSString*)keyPath treated:(NSString*)treatedMessagesPath value: (NSDictionary*)value {
    if (![[NSFileManager defaultManager] fileExistsAtPath:keyPath]) {
        return other;
    }
    NSData * data = [[NSFileManager defaultManager] contentsAtPath:keyPath];
    const uint8_t *bytes = (const uint8_t*)[data bytes];
    dht::crypto::PrivateKey dhtKey(bytes, [data length], "");

    Json::Value jsonValue = toJson(value);
    dht::Value dhtValue(jsonValue);

    if (isMessageTreated(dhtValue.id, [treatedMessagesPath UTF8String]) || !dhtValue.isEncrypted()) {
        return other;
    }
    try {
        dht::Value decrypted = decryptDhtValue(dhtKey, dhtValue);
        auto peerDeviceId = decrypted.owner->getLongId().toString();
        auto unpacked = msgpack::unpack((const char*)decrypted.data.data(), decrypted.data.size());
        auto peerCR = unpacked.get().as<PeerConnectionRequest>();
        if (peerCR.forceSocket) {
            return call;
        }
    } catch(std::runtime_error error) {
        NSLog(@"******decryption failed");
    }
    return other;
}

Json::Value toJson(NSDictionary* value) {
    Json::Value val;
    for (NSString* key in value.allKeys) {
        if ([[value objectForKey:key] isKindOfClass:[NSString class]]) {
            NSString* stringValue = [value objectForKey:key];
            val[key.UTF8String] = stringValue.UTF8String;
        }
        else if ([[value objectForKey:key] isKindOfClass:[NSNumber class]]) {
            NSNumber* number = [value objectForKey:key];
            if ([key isEqualToString: @"id"]) {
                unsigned long long int intValue = [number unsignedLongLongValue];
                val[key.UTF8String] = intValue;
            } else {
                int intValue = [number intValue];
                val[key.UTF8String] = intValue;
            }
        }
    }
    return val;
}

#pragma mark value
template<typename ID = dht::Value::Id>
std::set<ID, std::less<>>
loadIdList(const std::string& path)
{
    std::set<ID, std::less<>> ids;
    std::ifstream file = std::ifstream(path, std::ios_base::in);
    if (!file.is_open()) {
        return ids;
    }
    std::string line;
    while (std::getline(file, line)) {
        if constexpr (std::is_same<ID, std::string>::value) {
            ids.emplace(std::move(line));
        } else if constexpr (std::is_integral<ID>::value) {
            ID vid;
            if (auto [p, ec] = std::from_chars(line.data(), line.data() + line.size(), vid, 16);
                ec == std::errc()) {
                ids.emplace(vid);
            }
        }
    }
    return ids;
}

bool isMessageTreated(dht::Value::Id messageId, const std::string& path)
{
    std::set<dht::Value::Id, std::less<>> treatedMessages_ = loadIdList(path);
    auto res = treatedMessages_.emplace(messageId);
    return !res.second;
}

dht::Value
decryptDhtValue(const dht::crypto::PrivateKey& key, const dht::Value& v)
{
    if (not v.isEncrypted())
        throw std::runtime_error("Data is not encrypted.");
    
    auto decrypted = key.decrypt(v.cypher);
    
    dht::Value ret {v.id};
    auto msg = msgpack::unpack((const char*)decrypted.data(), decrypted.size());
    ret.msgpack_unpack_body(msg.get());
    
    if (ret.recipient != key.getPublicKey().getId())
        throw std::runtime_error("Recipient mismatch");
    if (not ret.owner or not ret.owner->checkSignature(ret.getToSign(), ret.signature))
        throw std::runtime_error("Signature mismatch");
    
    return ret;
}

@end
