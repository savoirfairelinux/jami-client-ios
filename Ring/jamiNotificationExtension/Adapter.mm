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
#import "Utils.h"
#import "jamiNotificationExtension-Swift.h"

#import "jami/jami.h"
#import "jami/configurationmanager_interface.h"
#import "jami/callmanager_interface.h"
#import "jami/conversation_interface.h"
#import "jami/datatransfer_interface.h"

#define MSGPACK_DISABLE_LEGACY_NIL
#import "opendht/crypto.h"
#import "opendht/default_types.h"
#import "dhtnet/fileutils.h"
#import "yaml-cpp/yaml.h"

#import "json/json.h"
#import "fstream"
#import "charconv"

@implementation Adapter

static id<AdapterDelegate> _delegate;

using namespace libjami;

struct PeerConnectionRequest : public dht::EncryptedValue<PeerConnectionRequest>
{
    static const constexpr dht::ValueType& TYPE = dht::ValueType::USER_DATA;
    static constexpr const char* key_prefix = "peer:";
    dht::Value::Id id = dht::Value::INVALID_ID;
    std::string ice_msg {};
    bool isAnswer {false};
    std::string connType {};
    MSGPACK_DEFINE_MAP(id, ice_msg, isAnswer, connType)
};

// Constants
const std::string fileSeparator = "/";
NSString* const certificates = @"certificates";
NSString* const crls = @"crls";
NSString* const ocsp = @"ocsp";
NSString* const nameCache = @"namecache";
NSString* const defaultNameServer = @"ns.jami.net";
std::string const nameServerConfiguration = "RingNS.uri";
NSString* const accountConfig = @"config.yml";
constexpr auto ID_TIMEOUT = std::chrono::hours(24);

std::map<std::string, std::shared_ptr<CallbackWrapperBase>> confHandlers;
std::map<std::string, std::string> cachedNames;
std::map<std::string, std::string> nameServers;

#pragma mark Callbacks registration
- (void)registerSignals
{
    confHandlers.insert(exportable_callback<ConfigurationSignal::GetAppDataPath>(
                                                                                 [](const std::string& name, std::vector<std::string>* ret) {
                                                                                     if (name == "cache") {
                                                                                         auto path = [Constants cachesPath];
                                                                                         ret->push_back(std::string([path.path UTF8String]));
                                                                                     } else {
                                                                                         auto path = [Constants documentsPath];
                                                                                         ret->push_back(std::string([path.path UTF8String]));
                                                                                     }
                                                                                 }));

    confHandlers.insert(exportable_callback<ConversationSignal::MessageReceived>(
                                                                                 [weakDelegate = Adapter.delegate](const std::string& accountId,
                                                                                                                   const std::string& conversationId,
                                                                                                                   std::map<std::string, std::string> message) {
                                                                                                                       id<AdapterDelegate> delegate = weakDelegate;
                                                                                                                       if (delegate) {
                                                                                                                           NSString* convId = [NSString stringWithUTF8String:conversationId.c_str()];
                                                                                                                           NSString* account = [NSString stringWithUTF8String:accountId.c_str()];
                                                                                                                           NSMutableDictionary* interaction = [Utils mapToDictionnary:message];
                                                                                                                           [delegate newInteractionWithConversationId:convId
                                                                                                                                                            accountId:account
                                                                                                                                                              message:interaction];
                                                                                                                       }
                                                                                                                   }));

    confHandlers.insert(exportable_callback<DataTransferSignal::DataTransferEvent>(
                                                                                   [weakDelegate = Adapter.delegate](const std::string& account_id,
                                                                                                                     const std::string& conversation_id,
                                                                                                                     const std::string& interaction_id,
                                                                                                                     const std::string& file_id,
                                                                                                                     int eventCode) {
                                                                                                                         id<AdapterDelegate> delegate = weakDelegate;
                                                                                                                         if (delegate) {
                                                                                                                             NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
                                                                                                                             NSString* conversationId = [NSString stringWithUTF8String:conversation_id.c_str()];
                                                                                                                             NSString* fileId = [NSString stringWithUTF8String:file_id.c_str()];
                                                                                                                             NSString* interactionId = [NSString stringWithUTF8String:interaction_id.c_str()];
                                                                                                                             [delegate dataTransferEventWithFileId:fileId
                                                                                                                                                     withEventCode:eventCode
                                                                                                                                                         accountId:accountId
                                                                                                                                                    conversationId:conversationId
                                                                                                                                                     interactionId:interactionId];
                                                                                                                         }
                                                                                                                     }));

    confHandlers.insert(exportable_callback<ConversationSignal::ConversationSyncFinished>(
                                                                                          [weakDelegate = Adapter.delegate](const std::string& account_id) {
                                                                                              id<AdapterDelegate> delegate = weakDelegate;
                                                                                              if (delegate) {
                                                                                                  NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
                                                                                                  [delegate conversationSyncCompletedWithAccountId:accountId];
                                                                                              }
                                                                                          }));

    confHandlers.insert(exportable_callback<ConversationSignal::ConversationCloned>(
                                                                                    [weakDelegate = Adapter.delegate](const std::string& account_id) {
                                                                                        id<AdapterDelegate> delegate = weakDelegate;
                                                                                        if (delegate) {
                                                                                            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
                                                                                            [delegate conversationClonedWithAccountId:accountId];
                                                                                        }
                                                                                    }));

    confHandlers.insert(exportable_callback<ConversationSignal::ConversationRequestReceived>([weakDelegate = Adapter.delegate](const std::string& accountId, const std::string& conversationId, std::map<std::string, std::string> metadata) {
        id<AdapterDelegate> delegate = weakDelegate;
        if (delegate) {
            NSString* accountIdStr = [NSString stringWithUTF8String:accountId.c_str()];
            NSString* convIdStr = [NSString stringWithUTF8String:conversationId.c_str()];
            NSMutableDictionary* info = [Utils mapToDictionnary: metadata];
            [delegate receivedConversationRequestWithAccountId: accountIdStr conversationId: convIdStr metadata:info];
        }
    }));
    registerSignalHandlers(confHandlers);
}

#pragma mark AdapterDelegate
+ (id<AdapterDelegate>)delegate
{
    return _delegate;
}

+ (void)setDelegate:(id<AdapterDelegate>)delegate
{
    _delegate = delegate;
}

- (bool)downloadFileWithFileId:(NSString*)fileId
                     accountId:(NSString*)accountId
                conversationId:(NSString*)conversationId
                 interactionId:(NSString*)interactionId
                  withFilePath:(NSString*)filePath
{
    return downloadFile(std::string([accountId UTF8String]),
                        std::string([conversationId UTF8String]),
                        std::string([interactionId UTF8String]),
                        std::string([fileId UTF8String]),
                        std::string([filePath UTF8String]));
}

- (BOOL)start:(NSString*)accountId
{
    [self registerSignals];
    if (initialized() == true) {
        reloadConversationsAndRequests(std::string([accountId UTF8String]));
        setAccountActive(std::string([accountId UTF8String]), true);
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
    unregisterSignalHandlers();
    confHandlers.clear();
    [self setAccountsActive:false];
}

- (void)setAccountsActive:(BOOL)active
{
    auto accounts = getAccountList();
    for (auto account : accounts) {
        if (active) {
            reloadConversationsAndRequests(account);
        }
        setAccountActive(account, active, true);
    }
}

- (void)pushNotificationReceived:(NSString*)from message:(NSDictionary*)data {
    pushNotificationReceived(std::string([from UTF8String]), [Utils dictionnaryToMap:data]);
}

- (NSDictionary<NSString*, NSString*>*)decrypt:(NSString*)keyPath
                                       accountId:(NSString*)accountId
                                       treated:(NSString*)treatedMessagesPath
                                         value:(NSDictionary*)value
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:keyPath]) {
        return {};
    }

    NSData* data = [[NSFileManager defaultManager] contentsAtPath:keyPath];
    const uint8_t* bytes = (const uint8_t*) [data bytes];
    dht::crypto::PrivateKey dhtKey(bytes, [data length], "");

    Json::Value jsonValue = toJson(value);
    dht::Value dhtValue(jsonValue);

    if (!dhtValue.isEncrypted()) {
        return {};
    }
    try {
        dht::Sp<dht::Value> decrypted = dhtValue.decrypt(dhtKey);
        auto unpacked = msgpack::unpack((const char*) decrypted->data.data(), decrypted->data.size());
        auto peerCR = unpacked.get().as<PeerConnectionRequest>();
        if (peerCR.connType.empty()) {
            // this value is not a PeerConnectionRequest
            // check if it a TrustRequest
            auto conversationRequest = unpacked.get().as<dht::TrustRequest>();
            if (conversationRequest.confirm) {
                // request confirmation. We need to wait for conversation to clone
                return @{@"": @"application/clone"};
            }
            if (!conversationRequest.conversationId.empty()) {
                if (conversationRequest.service == "cx.ring") {
                    // return git message type to start daemon
                    return @{@"": @"application/im-gitmessage-id"};
                }
            }
            return {};
        }
        if (isMessageTreated(peerCR.id, [treatedMessagesPath UTF8String])) {
            return {};
        }

        std::string peerId = "";
        if (peerCR.connType == "videoCall" || peerCR.connType == "audioCall") {
            auto certPath = [[[Constants documentsPath] URLByAppendingPathComponent:accountId] URLByAppendingPathComponent:certificates].path.UTF8String;
            auto crlPath = [[[Constants documentsPath] URLByAppendingPathComponent:accountId] URLByAppendingPathComponent:crls].path.UTF8String;
            auto ocspPath = [[[Constants documentsPath] URLByAppendingPathComponent:accountId] URLByAppendingPathComponent:ocsp].path.UTF8String;
            peerId = getPeerId(decrypted->owner->getId().toString(),
                               certPath,
                               crlPath,
                               ocspPath);
        }
        return @{@(peerId.c_str()): @(peerCR.connType.c_str())};
    } catch (std::runtime_error error) {
    }
    return {};
}

-(NSString*)getNameFor:(NSString*)address accountId:(NSString*)accountId {
    return @(getName(std::string([address UTF8String]), std::string([accountId UTF8String])).c_str());
}

-(NSString*)nameServerForAccountId:(NSString*)accountId; {
    auto nameServer = getNameServer(std::string([accountId UTF8String]));
    return nameServer.empty() ? defaultNameServer : @(nameServer.c_str());
}

Json::Value
toJson(NSDictionary* value)
{
    Json::Value val;
    for (NSString* key in value.allKeys) {
        if ([[value objectForKey:key] isKindOfClass:[NSString class]]) {
            NSString* stringValue = [value objectForKey:key];
            val[key.UTF8String] = stringValue.UTF8String;
        } else if ([[value objectForKey:key] isKindOfClass:[NSNumber class]]) {
            NSNumber* number = [value objectForKey:key];
            if ([key isEqualToString:@"id"]) {
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

std::string getName(std::string addres, std::string accountId)
{
    auto name = cachedNames.find(addres);
    if (name != cachedNames.end()) {
        return name->second;
    }

    auto ns = getNameServer(accountId);
    NSURL *url = [NSURL URLWithString: @(ns.c_str())];
    NSString* host = [url host];
    NSString* nameServer = host.length == 0 ? defaultNameServer : host;
    std::string namesPath = [[[Constants cachesPath] URLByAppendingPathComponent: nameCache] URLByAppendingPathComponent: nameServer].path.UTF8String;

    msgpack::unpacker pac;
    // read file
    std::ifstream file = std::ifstream(namesPath, std::ios_base::in);
    if (!file.is_open()) {
        return "";
    }
    std::string line;
    while (std::getline(file, line)) {
        pac.reserve_buffer(line.size());
        memcpy(pac.buffer(), line.data(), line.size());
        pac.buffer_consumed(line.size());
    }

    // load values
    msgpack::object_handle oh;
    if (pac.next(oh))
        oh.get().convert(cachedNames);
    auto cacheRes = cachedNames.find(addres);
    return cacheRes != cachedNames.end() ? cacheRes->second : std::string {};
}

std::string getNameServer(std::string accountId) {
    auto it = nameServers.find(accountId);
    if (it != nameServers.end()) {
        return it->second;
    }
    std::string nameServer {};
    auto accountConfigPath = [[[Constants documentsPath] URLByAppendingPathComponent: @(accountId.c_str())] URLByAppendingPathComponent: accountConfig].path.UTF8String;
    try {
        std::ifstream file = std::ifstream(accountConfigPath, std::ios_base::in);
        YAML::Node node = YAML::Load(file);
        file.close();
        nameServer = node[nameServerConfiguration].as<std::string>();
        if (!nameServer.empty()) {
            nameServers.insert(std::pair<std::string, std::string>(accountId, nameServer));
        }
    } catch (const std::exception& e) {}
    return nameServer;
}

#pragma mark functions copied from the daemon

#define LIKELY(expr)   (expr)
#define UNLIKELY(expr) (expr)

/*
 * Check whether a Unicode (5.2) char is in a valid range.
 *
 * The first check comes from the Unicode guarantee to never encode
 * a point above 0x0010ffff, since UTF-16 couldn't represent it.
 *
 * The second check covers surrogate pairs (category Cs).
 *
 * @param Char the character
 */
#define UNICODE_VALID(Char) ((Char) < 0x110000 && (((Char) &0xFFFFF800) != 0xD800))

#define CONTINUATION_CHAR \
    if ((*(unsigned char*) p & 0xc0) != 0x80) /* 10xxxxxx */ \
        goto error; \
    val <<= 6; \
    val |= (*(unsigned char*) p) & 0x3f;

std::string
getPeerId(const std::string& key,
          const std::string& certPath,
          const std::string& crlPath,
          const std::string& ocspPath)
{
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
        } catch (const std::exception& e) {
        }
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

void
loadRevocations(dht::crypto::Certificate& crt,
                const std::string& crlPath,
                const std::string& ocspPath)
{
    auto dir = crlPath + fileSeparator + crt.getId().toString();
    for (const auto& crl : readDirectory(dir)) {
        try {
            crt.addRevocationList(
                std::make_shared<dht::crypto::RevocationList>(loadFile(dir + fileSeparator + crl)));
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
foundPeerDevice(const std::shared_ptr<dht::crypto::Certificate>& crt, dht::InfoHash& account_id)
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
readDirectory(const std::string& dir)
{
    NSError* error;
    NSFileManager* fileMgr = [NSFileManager defaultManager];
    NSArray* files = [fileMgr contentsOfDirectoryAtPath:@(dir.c_str()) error:&error];

    std::vector<std::string> vector;
    for (NSString* fileName in files) {
        vector.push_back([fileName UTF8String]);
    }
    return vector;
}

std::vector<uint8_t>
loadFile(const std::string& path)
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:@(path.c_str())]) {
        return {};
    }
    NSData* data = [[NSFileManager defaultManager] contentsAtPath:@(path.c_str())];
    return [Utils vectorOfUInt8FromData:data];
}

std::string
utf8_make_valid(const std::string& name)
{
    ssize_t remaining_bytes = name.size();
    ssize_t valid_bytes;
    const char* remainder = name.c_str();
    const char* invalid;
    char* str = NULL;
    char* pos = nullptr;

    while (remaining_bytes != 0) {
        if (utf8_validate_c_str(remainder, remaining_bytes, &invalid))
            break;

        valid_bytes = invalid - remainder;

        if (str == NULL)
            // If every byte is replaced by U+FFFD, max(strlen(string)) == 3 * name.size()
            str = new char[3 * remaining_bytes];

        pos = str;

        strncpy(pos, remainder, valid_bytes);
        pos += valid_bytes;

        /* append U+FFFD REPLACEMENT CHARACTER */
        pos[0] = '\357';
        pos[1] = '\277';
        pos[2] = '\275';

        pos += 3;

        remaining_bytes -= valid_bytes + 1;
        remainder = invalid + 1;
    }

    if (str == NULL)
        return std::string(name);

    strncpy(pos, remainder, remaining_bytes);
    pos += remaining_bytes;

    std::string answer(str, pos - str);
    assert(utf8_validate_c_str(answer.c_str(), -1, NULL));

    delete[] str;

    return answer;
}

bool
utf8_validate_c_str(const char* str, ssize_t max_len, const char** end)
{
    const char* p;

    if (max_len < 0)
        p = fast_validate(str);
    else
        p = fast_validate_len(str, max_len);

    if (end)
        *end = p;

    if ((max_len >= 0 && p != str + max_len) || (max_len < 0 && *p != '\0'))
        return false;
    else
        return true;
}

static const char*
fast_validate(const char* str)
{
    char32_t val = 0;
    char32_t min = 0;
    const char* p;

    for (p = str; *p; p++) {
        if (*(unsigned char*) p < 128)
            /* done */;
        else {
            const char* last;

            last = p;

            if ((*(unsigned char*) p & 0xe0) == 0xc0) { /* 110xxxxx */
                if (UNLIKELY((*(unsigned char*) p & 0x1e) == 0))
                    goto error;

                p++;

                if (UNLIKELY((*(unsigned char*) p & 0xc0) != 0x80)) /* 10xxxxxx */
                    goto error;
            } else {
                if ((*(unsigned char*) p & 0xf0) == 0xe0) { /* 1110xxxx */
                    min = (1 << 11);
                    val = *(unsigned char*) p & 0x0f;
                    goto TWO_REMAINING;
                } else if ((*(unsigned char*) p & 0xf8) == 0xf0) { /* 11110xxx */
                    min = (1 << 16);
                    val = *(unsigned char*) p & 0x07;
                } else
                    goto error;

                p++;
                CONTINUATION_CHAR;
            TWO_REMAINING:
                p++;
                CONTINUATION_CHAR;
                p++;
                CONTINUATION_CHAR;

                if (UNLIKELY(val < min))
                    goto error;

                if (UNLIKELY(!UNICODE_VALID(val)))
                    goto error;
            }

            continue;

        error:
            return last;
        }
    }

    return p;
}

static const char*
fast_validate_len(const char* str, ssize_t max_len)
{
    char32_t val = 0;
    char32_t min = 0;
    const char* p;

    assert(max_len >= 0);

    for (p = str; ((p - str) < max_len) && *p; p++) {
        if (*(unsigned char*) p < 128)
            /* done */;
        else {
            const char* last;

            last = p;

            if ((*(unsigned char*) p & 0xe0) == 0xc0) { /* 110xxxxx */
                if (UNLIKELY(max_len - (p - str) < 2))
                    goto error;

                if (UNLIKELY((*(unsigned char*) p & 0x1e) == 0))
                    goto error;

                p++;

                if (UNLIKELY((*(unsigned char*) p & 0xc0) != 0x80)) /* 10xxxxxx */
                    goto error;
            } else {
                if ((*(unsigned char*) p & 0xf0) == 0xe0) { /* 1110xxxx */
                    if (UNLIKELY(max_len - (p - str) < 3))
                        goto error;

                    min = (1 << 11);
                    val = *(unsigned char*) p & 0x0f;
                    goto TWO_REMAINING;
                } else if ((*(unsigned char*) p & 0xf8) == 0xf0) { /* 11110xxx */
                    if (UNLIKELY(max_len - (p - str) < 4))
                        goto error;

                    min = (1 << 16);
                    val = *(unsigned char*) p & 0x07;
                } else
                    goto error;

                p++;
                CONTINUATION_CHAR;
            TWO_REMAINING:
                p++;
                CONTINUATION_CHAR;
                p++;
                CONTINUATION_CHAR;

                if (UNLIKELY(val < min))
                    goto error;

                if (UNLIKELY(!UNICODE_VALID(val)))
                    goto error;
            }

            continue;

        error:
            return last;
        }
    }

    return p;
}

bool
isMessageTreated(uint64_t id, const std::string& path)
{
    std::map<uint64_t, std::chrono::system_clock::time_point> valid_ids;
    auto now = std::chrono::system_clock::now();
    auto timeout = now - ID_TIMEOUT;

    try {
        std::ifstream file(path, std::ios::binary);
        if (!file.is_open()) {
            throw std::runtime_error("Unable to open file.");
        }

        msgpack::unpacker unp;
        while (!file.eof()) {
            unp.reserve_buffer(8 * 1024);
            file.read(unp.buffer(), unp.buffer_capacity());
            unp.buffer_consumed(file.gcount());

            msgpack::unpacked result;
            while (unp.next(result)) {
                auto kv = result.get().as<std::pair<uint64_t, std::chrono::system_clock::time_point>>();
                if (kv.second > timeout) {
                    valid_ids.insert(std::move(kv));
                }
            }
        }
    } catch (const std::exception& e) {}

    return valid_ids.find(id) != valid_ids.end();
}

@end
