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
#import "jami/datatransfer_interface.h"
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
    std::string connType {};
    MSGPACK_DEFINE_MAP(id, ice_msg, isAnswer, connType)
};

typedef NS_ENUM(NSInteger, NotificationType) {
    videoCall,
    audioCall,
    gitMessage,
    unknown
};

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

static constexpr const char MIME_TYPE_GIT[] {"application/im-gitmessage-id"};
static constexpr const char MIME_TYPE_TEXT_PLAIN[] {"text/plain"};

// Constants
const std::string fileSeparator = "/";
NSString *const certificates = @"certificates";
NSString *const crls = @"crls";
NSString *const ocsp = @"ocsp";
std::map<std::string, std::shared_ptr<CallbackWrapperBase>> confHandlers;

#pragma mark Callbacks registration
- (void)registerConfigurationHandler {
    //std::map<std::string, std::shared_ptr<CallbackWrapperBase>> confHandlers;
    confHandlers.insert(exportable_callback<ConfigurationSignal::GetAppDataPath>([&](const std::string& name,
                                                                                     std::vector<std::string>* ret) {
        if (name == "cache") {
            NSURL *appGroupDirectoryPath = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier: @"group.com.savoirfairelinux.ring"];
            NSURL * cachesDocUrl = [[appGroupDirectoryPath URLByAppendingPathComponent:@"Library"] URLByAppendingPathComponent:@"Caches"];
            //auto path = [self getCachesPath];
            ret->push_back(std::string([cachesDocUrl.path UTF8String]));
        } else {
            NSURL *appGroupDirectoryPath = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier: @"group.com.savoirfairelinux.ring"];
            NSURL * groupDocUrl = [appGroupDirectoryPath URLByAppendingPathComponent:@"Documents"];
            ret->push_back(std::string([groupDocUrl.path UTF8String]));
        }
    }));
    
    confHandlers.insert(exportable_callback<ConversationSignal::MessageReceived>([&](const std::string& accountId, const std::string& conversationId, std::map<std::string, std::string> message) {
        NSLog(@"&&&&&&MessageReceived");
        if (Adapter.delegate) {
            NSString* convId =  [NSString stringWithUTF8String:conversationId.c_str()];
            NSString* account =  [NSString stringWithUTF8String:accountId.c_str()];
            NSMutableDictionary* interaction = [Utils mapToDictionnary: message];
            [Adapter.delegate newInteractionWithConversationId:convId accountId:account message: interaction];
        }
    }));
    confHandlers
    .insert(exportable_callback<DataTransferSignal::DataTransferEvent>([&](const std::string& account_id,
                                                                           const std::string& conversation_id,
                                                                           const std::string& interaction_id,
                                                                           const std::string& file_id,
                                                                           int eventCode) {
        if(Adapter.delegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* conversationId = [NSString stringWithUTF8String:conversation_id.c_str()];
            NSString* fileId = [NSString stringWithUTF8String:file_id.c_str()];
            NSString* interactionId = [NSString stringWithUTF8String:interaction_id.c_str()];
            [Adapter.delegate dataTransferEventWithFileId: fileId withEventCode: eventCode accountId: accountId conversationId: conversationId interactionId: interactionId];
        }
    }));
    confHandlers
    .insert(exportable_callback<ConversationSignal::ConversationSyncEvent>([&](const std::string& account_id) {
        if(Adapter.delegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            [Adapter.delegate conversationSyncCompletedWithAccountId: accountId];
        }
    }));
    confHandlers
    .insert(exportable_callback<ConversationSignal::CallConnectionRequest>([&](const std::string& account_id, const std::string& peer_id, bool hasVideo) {
        if(Adapter.delegate) {
            NSString* accountId = [NSString stringWithUTF8String:account_id.c_str()];
            NSString* peerId = [NSString stringWithUTF8String:peer_id.c_str()];
            [Adapter.delegate receivedCallConnectionRequestWithAccountId: accountId peerId: peerId hasVideo: hasVideo];
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
    NSURL * cachesDocUrl = [[appGroupDirectoryPath URLByAppendingPathComponent:@"Library"] URLByAppendingPathComponent:@"Caches"];
    return cachesDocUrl;
}

- (bool)downloadSwarmTransferWithFileId:(NSString*)fileId
                              accountId:(NSString*)accountId
                         conversationId:(NSString*)conversationId
                          interactionId:(NSString*)interactionId
                           withFilePath:(NSString*)filePath {
    return downloadFile(std::string([accountId UTF8String]), std::string([conversationId UTF8String]), std::string([interactionId UTF8String]), std::string([fileId UTF8String]), std::string([filePath UTF8String]));
}

- (BOOL)startDaemon {
    if (DRing::initialized() == true) {
        [self registerConfigurationHandler];
        [self setAccountsActive: true];
        return true;
    }
    [self registerConfigurationHandler];
    if (![[NSThread currentThread] isMainThread]) {
        __block bool success;
        dispatch_sync(dispatch_get_main_queue(), ^{
            auto initSuccess = init(static_cast<DRing::InitFlag>(0));
            auto startSuccess = start({});
            success = initSuccess && startSuccess;
        });
        return success;
    }
    else {
        auto initSuccess = init(static_cast<DRing::InitFlag>(0));
        auto startSuccess = start({});
        return initSuccess && startSuccess;
    }
}

- (void)stopDaemon {
    unregisterSignalHandlers();
    confHandlers.clear();
    [self setAccountsActive: false];
}

-(void)setAccountsActive:(BOOL) active {
    auto accounts = getAccountList();
    for(auto account: accounts) {
        setAccountActive(account, active);
    }
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
        case gitMessage:
            return @{peerId : @"gitMessage"};
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
        auto type = peerCR.connType;
        if (type == "videoCall") {
            return [self getReturnValueOfType: videoCall peerId: @(peerId.c_str())];
        } else if (type == "audioCall") {
            return [self getReturnValueOfType: audioCall peerId: @(peerId.c_str())];
        } else if (type == "sync" || type == "application/im-gitmessage-id") {
            return [self getReturnValueOfType: gitMessage peerId: @""];
        }
    } catch(std::runtime_error error) {
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

std::string
utf8_make_valid(const std::string& name)
{
    ssize_t remaining_bytes = name.size();
    ssize_t valid_bytes;
    const char* remainder = name.c_str();
    const char* invalid;
    char* str = NULL;
    char* pos;

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

@end
