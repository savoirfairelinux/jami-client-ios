/*
 *  Copyright (C) 2025-2025 Savoir-faire Linux Inc.
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

+ (NSMutableDictionary*)mapToDictionnary:(const std::map<std::string, std::string>&)map
{
    NSMutableDictionary* resDictionnary = [NSMutableDictionary new];

    std::for_each(map.begin(), map.end(), ^(std::pair<std::string, std::string> keyValue) {
        id key = [NSString stringWithUTF8String:keyValue.first.c_str()];
        id value = [NSString stringWithUTF8String:keyValue.second.c_str()];
        [resDictionnary setObject:value forKey:key];
    });

    return resDictionnary;
}

+ (NSArray*)vectorOfMapsToArray:
(const std::vector<std::map<std::string, std::string>>&)vectorOfMaps {
    NSMutableArray* array = [[NSMutableArray alloc] initWithCapacity:vectorOfMaps.size()];

    std::for_each(vectorOfMaps.begin(), vectorOfMaps.end(), ^(std::map<std::string, std::string> map) {
        NSDictionary *dictionary = [Utils mapToDictionnary:map];
        [array addObject:dictionary];
    });

    return [NSArray arrayWithArray:array];
}

+ (NSMutableDictionary*)mapToDictionnaryWithInt:(const std::map<std::string, int32_t>&)map
{
    NSMutableDictionary* resDictionnary = [NSMutableDictionary new];

    std::for_each(map.begin(), map.end(), ^(std::pair<std::string, int32_t> keyValue) {
        id key = [NSString stringWithUTF8String:keyValue.first.c_str()];
        id value = [NSNumber numberWithInt:keyValue.second];
        [resDictionnary setObject:value forKey:key];
    });

    return resDictionnary;
}


@end
