/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
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

#import <Foundation/Foundation.h>

#import <map>
#import <string>
#import <vector>

@interface Utils : NSObject

+ (NSArray*)vectorToArray:(const std::vector<std::string>&)vector;
+ (NSMutableDictionary*)mapToDictionnary:
    (const std::map<std::string, std::string>&)map;
+ (std::map<std::string, std::string>)dictionnaryToMap:(NSDictionary*)dict;
+ (NSArray*)vectorOfMapsToArray:(const std::vector<std::map<std::string, std::string>>&)vectorOfMaps;
+ (NSData*)dataFromVectorOfUInt8:(std::vector<uint8_t>)vectorOfUInt8;
+ (std::vector<uint8_t>)vectorOfUInt8FromData:(NSData*)data;


@end
