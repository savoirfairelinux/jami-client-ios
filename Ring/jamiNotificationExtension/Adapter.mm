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

typedef NS_ENUM(NSInteger, NotificationType) {
    videoCall,
    audioCall,
    message,
    fileTransfer,
    unknown
};

// Constants
const std::string fileSeparator = "/";
NSString *const certificates = @"certificates";
NSString *const crls = @"crls";
NSString *const ocsp = @"ocsp";

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
            ret->push_back(std::string([[self getCachesPath].path UTF8String]));
        } else {
            ret->push_back(std::string([[self getDocumentsPath].path UTF8String]));
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

-(NSURL*)getDocumentsPath {
    NSURL *appGroupDirectoryPath = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier: @"group.com.savoirfairelinux.ring"];
    NSURL * groupDocUrl = [appGroupDirectoryPath URLByAppendingPathComponent:@"Documents"];
    return groupDocUrl;
}

-(NSURL*)getCachesPath {
    NSURL *appGroupDirectoryPath = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier: @"group.com.savoirfairelinux.ring"];
    NSURL * groupDocUrl = [appGroupDirectoryPath URLByAppendingPathComponent:@"Library/Caches"];
    return groupDocUrl;
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

- (NSDictionary<NSString*, NSString*>*) getReturnValueOfType:(NotificationType)type peerId:(NSString*)peerId {
    switch (type) {
        case videoCall:
            return @{peerId : @"videoCall"};
            break;
        case audioCall:
            return @{peerId : @"audioCall"};
            break;
        case message:
            return @{peerId : @"message"};
            break;
        case fileTransfer:
            return @{peerId : @"fileTransfer"};
            break;
        default:
            return @{@"" : @"unknown"};
            break;
    }
}

- (NSDictionary<NSString*, NSString*>*)decrypt:(NSString*)keyPath treated:(NSString*)treatedMessagesPath value: (NSDictionary*)value {
    NSDictionary *result = [self getReturnValueOfType: unknown peerId: @""];
    if (![[NSFileManager defaultManager] fileExistsAtPath:keyPath]) {
        return result;
    }
    NSData * data = [[NSFileManager defaultManager] contentsAtPath:keyPath];
    const uint8_t *bytes = (const uint8_t*)[data bytes];
    dht::crypto::PrivateKey dhtKey(bytes, [data length], "");

    Json::Value jsonValue = toJson(value);
    dht::Value dhtValue(jsonValue);

    if (!dhtValue.isEncrypted()) {
        return result;
    }
    try {
        dht::Value decrypted = decryptDhtValue(dhtKey, dhtValue);
        auto unpacked = msgpack::unpack((const char*)decrypted.data.data(), decrypted.data.size());
        auto peerCR = unpacked.get().as<PeerConnectionRequest>();
        if (isMessageTreated(peerCR.id, [treatedMessagesPath UTF8String])) {
            return result;
        }
        auto certPath = [[self getDocumentsPath] URLByAppendingPathComponent: certificates].path.UTF8String;
        auto crlPath = [[self getDocumentsPath] URLByAppendingPathComponent: crls].path.UTF8String;
        auto ocspPath = [[self getDocumentsPath] URLByAppendingPathComponent: ocsp].path.UTF8String;
        std::string peerId = getPeerId(decrypted.owner->getId().toString(),certPath, crlPath, ocspPath);
        if (peerId.empty()) {
            return result;
        }
        if (peerCR.forceSocket) {
            return [self getReturnValueOfType: videoCall peerId: @(peerId.c_str())];
        }
    } catch(std::runtime_error error) {
        NSLog(@"******decryption failed");
    }
    return result;
}

Json::Value toJson(NSDictionary* value) {
    Json::Value val;
    for (NSString* key in value.allKeys) {
        if ([[value objectForKey:key] isKindOfClass:[NSString class]]) {
            NSString* stringValue = [value objectForKey:key];
            val[key.UTF8String] = stringValue.UTF8String;
        } else if ([[value objectForKey:key] isKindOfClass:[NSNumber class]]) {
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

#pragma mark functions copied from the daemon
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

template<typename ID = dht::Value::Id>
bool isMessageTreated(ID messageId, const std::string& path)
{
    std::ifstream file = std::ifstream(path, std::ios_base::in);
    if (!file.is_open()) {
        return false;
    }
    std::set<ID, std::less<>> treatedMessages;
    std::string line;
    while (std::getline(file, line)) {
        if constexpr (std::is_same<ID, std::string>::value) {
            treatedMessages.emplace(std::move(line));
        } else if constexpr (std::is_integral<ID>::value) {
            ID vid;
            if (auto [p, ec] = std::from_chars(line.data(), line.data() + line.size(), vid, 16);
                ec == std::errc()) {
                treatedMessages.emplace(vid);
            }
        }
    }
    return treatedMessages.find(messageId) != treatedMessages.end();
}

std::string getPeerId(const std::string& key, const std::string& certPath, const std::string& crlPath, const std::string& ocspPath) {
    std::map<std::string, std::shared_ptr<dht::crypto::Certificate>> certs;
    auto dir_content = readDirectory(certPath);
    unsigned n = 0;
    for (const auto& f : dir_content) {
        try {
            auto crt = std::make_shared<dht::crypto::Certificate>(
                                                                  loadFile(certPath + fileSeparator + f));
            auto id = crt->getId().toString();
            auto longId = crt->getLongId().toString();
            if (id != f && longId != f)
                throw std::logic_error("Certificate id mismatch");
            while (crt) {
                id = crt->getId().toString();
                longId = crt->getLongId().toString();
                certs.emplace(std::move(id), crt);
                certs.emplace(std::move(longId), crt);
                loadRevocations(*crt, crlPath, ocspPath);
                crt = crt->issuer;
                ++n;
            }
        } catch (const std::exception& e) {}
    }
    auto cit = certs.find(key);
    if (cit == certs.cend()) {
        return {};
    }
    dht::InfoHash peer_account_id;
    if (not foundPeerDevice(cit->second, peer_account_id)) {
        return {};
    }
    return peer_account_id.toString();
}

void loadRevocations(dht::crypto::Certificate& crt, const std::string& crlPath, const std::string& ocspPath)
{
    auto dir = crlPath + fileSeparator + crt.getId().toString();
    for (const auto& crl : readDirectory(dir)) {
        try {
            crt.addRevocationList(std::make_shared<dht::crypto::RevocationList>(
                                                                                loadFile(dir + fileSeparator + crl)));
        } catch (const std::exception& e) {
        }
    }
    auto ocsp_dir = ocspPath + fileSeparator + crt.getId().toString();
    for (const auto& ocsp : readDirectory(ocsp_dir)) {
        try {
            std::string ocsp_filepath = ocsp_dir + fileSeparator + ocsp;
            auto serial = crt.getSerialNumber();
            if (dht::toHex(serial.data(), serial.size()) != ocsp)
                continue;
            dht::Blob ocspBlob = loadFile(ocsp_filepath);
            crt.ocspResponse = std::make_shared<dht::crypto::OcspResponse>(ocspBlob.data(),
                                                                           ocspBlob.size());
        } catch (const std::exception& e) {
        }
    }
}

bool
foundPeerDevice(const std::shared_ptr<dht::crypto::Certificate>& crt,
                dht::InfoHash& account_id)
{
    if (not crt)
        return false;
    
    auto top_issuer = crt;
    while (top_issuer->issuer)
        top_issuer = top_issuer->issuer;
    
    if (top_issuer == crt) {
        return false;
    }
    dht::crypto::TrustList peer_trust;
    peer_trust.add(*top_issuer);
    if (not peer_trust.verify(*crt)) {
        return false;
    }
    if (crt->ocspResponse and crt->ocspResponse->getCertificateStatus() != GNUTLS_OCSP_CERT_GOOD) {
        return false;
    }
    account_id = crt->issuer->getId();
    return true;
}

std::vector<std::string>
readDirectory(const std::string& dir) {
    NSError *error;
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSArray *files=[fileMgr contentsOfDirectoryAtPath:@(dir.c_str()) error:&error];
    
    std::vector<std::string> vector;
    for (NSString* fileName in files) {
        vector.push_back([fileName UTF8String]);
    }
    return vector;
}

std::vector<uint8_t>
loadFile(const std::string& path)
{
    if (![[NSFileManager defaultManager] fileExistsAtPath: @(path.c_str())]) {
        return {};
    }
    NSData * data = [[NSFileManager defaultManager] contentsAtPath: @(path.c_str())];
    return [Utils vectorOfUInt8FromData: data];
}
@end
