/*
 *  Copyright (C) 2021-22 Savoir-faire Linux Inc.
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

#import "Utils.h"

@implementation Utils

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

+ (std::vector<uint8_t>)vectorOfUInt8FromData:(NSData*)data
{
    std::vector<uint8_t> vector;
    char* bytes = (char*) data.bytes;

    for (int i = 0; i < data.length; i++) {
        vector.push_back(bytes[i]);
    }
    return vector;
}

@end
