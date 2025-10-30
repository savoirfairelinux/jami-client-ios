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

+ (std::vector<std::map<std::string, std::string>>)dictionaryArrayToMapVector:(NSArray*)dictionaries {
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

