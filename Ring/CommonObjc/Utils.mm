/*
 * Copyright (C) 2016-2025 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301
 * USA.
 */

#import "Utils.h"

#import <algorithm>

@implementation Utils

+ (NSArray*)vectorToArray:(const std::vector<std::string>&)vector {
    NSMutableArray* resArray = [NSMutableArray new];
    std::for_each(vector.begin(), vector.end(), ^(std::string str) {
        id nsstr = [NSString stringWithUTF8String:str.c_str()];
        [resArray addObject:nsstr];
    });
    return resArray;
}

+ (NSMutableDictionary*)mapToDictionary:
(const std::map<std::string, std::string>&)map {
    NSMutableDictionary* resDictionary = [NSMutableDictionary new];

    std::for_each(
                  map.begin(), map.end(), ^(std::pair<std::string, std::string> keyValue) {
                      id key = [NSString stringWithUTF8String:keyValue.first.c_str()];
                      id value = [NSString stringWithUTF8String:keyValue.second.c_str()];
                      [resDictionary setObject:value forKey:key];
                  });

    return resDictionary;
}

+ (NSMutableDictionary*)mapToDictionaryWithInt:(const std::map<std::string, int32_t>&)map
{
    NSMutableDictionary* resDictionary = [NSMutableDictionary new];

    std::for_each(map.begin(), map.end(), ^(std::pair<std::string, int32_t> keyValue) {
        id key = [NSString stringWithUTF8String:keyValue.first.c_str()];
        id value = [NSNumber numberWithInt:keyValue.second];
        [resDictionary setObject:value forKey:key];
    });

    return resDictionary;
}

+ (std::map<std::string, std::string>)dictionaryToMap:(NSDictionary*)dict {
    std::map<std::string, std::string> resMap;
    for (id key in dict)
        resMap.insert(std::pair<std::string, std::string>(
                                                          std::string([key UTF8String]),
                                                          std::string([[dict objectForKey:key] UTF8String])));
    return resMap;
}

+ (std::vector<std::map<std::string, std::string>>)arrayOfDictionariesToVectorOfMap:(NSArray*)dictionaries {
    std::vector<std::map<std::string, std::string>> resVector;
    for (NSDictionary* dictionary in dictionaries) {
        std::map<std::string, std::string> resMap;
        for (id key in dictionary) {
            resMap.insert(std::pair<std::string,
                          std::string>(
                                       std::string([key UTF8String]),
                                       std::string([[dictionary objectForKey:key] UTF8String])));
        }
        resVector.push_back(resMap);
    }
    return resVector;
}

+ (NSArray*)vectorOfMapsToArray:
(const std::vector<std::map<std::string, std::string>>&)vectorOfMaps {
    NSMutableArray* array = [[NSMutableArray alloc] initWithCapacity:vectorOfMaps.size()];

    std::for_each(
                  vectorOfMaps.begin(), vectorOfMaps.end(), ^(std::map<std::string, std::string> map) {
                      NSDictionary *dictionary = [Utils mapToDictionary:map];
                      [array addObject:dictionary];
                  });

    return [NSArray arrayWithArray:array];
}

+ (NSData*)dataFromVectorOfUInt8:(std::vector<uint8_t>)vectorOfUInt8 {

    NSMutableData* data = [[NSMutableData alloc] init];

    std::for_each(vectorOfUInt8.begin(), vectorOfUInt8.end(), ^(uint8_t byte) {
        [data appendBytes:&byte length:1];
    });

    return data;
}

+ (std::vector<uint8_t>)vectorOfUInt8FromData:(NSData*)data {

    std::vector<uint8_t> vector;
    char *bytes = (char*)data.bytes;

    for ( int i = 0; i < data.length; i++ ) {
        vector.push_back(bytes[i]);
    }
    return vector;
}

@end

#if DEBUG_TOOLS_ENABLED
#include <memory>

#include <opentelemetry/nostd/variant.h>
#include <opentelemetry/sdk/common/attribute_utils.h>
#include <opentelemetry/sdk/trace/span_data.h>

#include <cstdio>
#include <ctime>
#include <sstream>

namespace trace_sdk = ::opentelemetry::sdk::trace;

namespace {

std::string traceIdHexOTel(const opentelemetry::trace::TraceId& tid)
{
    char buf[33];
    tid.ToLowerBase16(opentelemetry::nostd::span<char, 32>{buf, 32});
    buf[32] = '\0';
    return buf;
}

std::string spanIdHexOTel(const opentelemetry::trace::SpanId& sid)
{
    char buf[17];
    sid.ToLowerBase16(opentelemetry::nostd::span<char, 16>{buf, 16});
    buf[16] = '\0';
    return buf;
}

std::string jsonEscapeOTel(const std::string& s)
{
    std::string out;
    out.reserve(s.size() + 8);
    for (char c : s) {
        switch (c) {
        case '"':
            out += "\\\"";
            break;
        case '\\':
            out += "\\\\";
            break;
        case '\n':
            out += "\\n";
            break;
        case '\r':
            out += "\\r";
            break;
        case '\t':
            out += "\\t";
            break;
        default:
            if (static_cast<unsigned char>(c) < 0x20) {
                char hex[8];
                std::snprintf(hex, sizeof(hex), "\\u%04x", static_cast<unsigned>(c));
                out += hex;
            } else {
                out += c;
            }
        }
    }
    return out;
}

std::string attrValueToJsonOTel(const ::opentelemetry::sdk::common::OwnedAttributeValue& val)
{
    namespace nostd = opentelemetry::nostd;
    if (nostd::holds_alternative<bool>(val))
        return nostd::get<bool>(val) ? "true" : "false";
    if (nostd::holds_alternative<int32_t>(val))
        return std::to_string(nostd::get<int32_t>(val));
    if (nostd::holds_alternative<uint32_t>(val))
        return std::to_string(nostd::get<uint32_t>(val));
    if (nostd::holds_alternative<int64_t>(val))
        return std::to_string(nostd::get<int64_t>(val));
    if (nostd::holds_alternative<uint64_t>(val))
        return std::to_string(nostd::get<uint64_t>(val));
    if (nostd::holds_alternative<double>(val))
        return std::to_string(nostd::get<double>(val));
    if (nostd::holds_alternative<std::string>(val))
        return "\"" + jsonEscapeOTel(nostd::get<std::string>(val)) + "\"";
    return "null";
}

std::string nanosToIsoOTel(opentelemetry::common::SystemTimestamp ts)
{
    auto ns = ts.time_since_epoch().count();
    auto secs = static_cast<time_t>(ns / 1000000000LL);
    auto frac = ns % 1000000000LL;
    struct tm utc {};
    gmtime_r(&secs, &utc);
    char buf[64];
    std::snprintf(buf, sizeof(buf),
                  "%04d-%02d-%02dT%02d:%02d:%02d.%09ldZ",
                  utc.tm_year + 1900, utc.tm_mon + 1, utc.tm_mday,
                  utc.tm_hour, utc.tm_min, utc.tm_sec, static_cast<long>(frac));
    return buf;
}

template<typename SpanRange>
std::string serializeDrainedSpansJson(const SpanRange& spans)
{
    std::ostringstream os;
    os << "[\n";

    bool first = true;
    for (const auto& sp : spans) {
        if (!first)
            os << ",\n";
        first = false;

        os << "  {\n";
        os << "    \"name\": \"" << jsonEscapeOTel(std::string(sp->GetName())) << "\",\n";
        os << "    \"traceId\": \"" << traceIdHexOTel(sp->GetTraceId()) << "\",\n";
        os << "    \"spanId\": \"" << spanIdHexOTel(sp->GetSpanId()) << "\",\n";
        os << "    \"parentSpanId\": \"" << spanIdHexOTel(sp->GetParentSpanId()) << "\",\n";
        os << "    \"startTime\": \"" << nanosToIsoOTel(sp->GetStartTime()) << "\",\n";
        auto endNs = sp->GetStartTime().time_since_epoch() + sp->GetDuration();
        opentelemetry::common::SystemTimestamp endTs(endNs);
        os << "    \"endTime\": \"" << nanosToIsoOTel(endTs) << "\",\n";
        os << "    \"status\": " << static_cast<int>(sp->GetStatus()) << ",\n";

        os << "    \"attributes\": {";
        {
            bool attrFirst = true;
            for (const auto& [key, val] : sp->GetAttributes()) {
                if (!attrFirst)
                    os << ",";
                attrFirst = false;
                os << "\n      \"" << jsonEscapeOTel(std::string(key)) << "\": "
                   << attrValueToJsonOTel(val);
            }
        }
        if (!sp->GetAttributes().empty())
            os << "\n    ";
        os << "},\n";

        os << "    \"events\": [";
        {
            bool evFirst = true;
            for (const auto& ev : sp->GetEvents()) {
                if (!evFirst)
                    os << ",";
                evFirst = false;
                os << "\n      {\"name\": \"" << jsonEscapeOTel(std::string(ev.GetName()))
                   << "\", \"timestamp\": \"" << nanosToIsoOTel(ev.GetTimestamp()) << "\""
                   << ", \"attributes\": {";
                bool eaFirst = true;
                for (const auto& [k, v] : ev.GetAttributes()) {
                    if (!eaFirst)
                        os << ",";
                    eaFirst = false;
                    os << "\"" << jsonEscapeOTel(std::string(k)) << "\": "
                       << attrValueToJsonOTel(v);
                }
                os << "}}";
            }
        }
        if (!sp->GetEvents().empty())
            os << "\n    ";
        os << "]\n";

        os << "  }";
    }

    os << "\n]\n";
    return os.str();
}

} // namespace

namespace jami_ios_telemetry {

std::string spansToJson(std::vector<std::unique_ptr<trace_sdk::SpanData>> spans)
{
    return serializeDrainedSpansJson(spans);
}

} // namespace jami_ios_telemetry
#endif // DEBUG_TOOLS_ENABLED

