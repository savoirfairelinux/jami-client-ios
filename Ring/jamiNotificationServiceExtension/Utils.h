//
//  Utils.h
//  jamiNotificationServiceExtension
//
//  Created by kateryna on 2021-06-08.
//  Copyright © 2021 Savoir-faire Linux. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <map>
#import <string>
#import <vector>

NS_ASSUME_NONNULL_BEGIN

@interface Utils : NSObject

+ (NSArray*)vectorToArray:(const std::vector<std::string>&)vector;
+ (NSMutableDictionary*)mapToDictionnary:
    (const std::map<std::string, std::string>&)map;
+ (std::map<std::string, std::string>)dictionnaryToMap:(NSDictionary*)dict;
+ (NSArray*)vectorOfMapsToArray:(const std::vector<std::map<std::string, std::string>>&)vectorOfMaps;
+ (NSData*)dataFromVectorOfUInt8:(std::vector<uint8_t>)vectorOfUInt8;
+ (std::vector<uint8_t>)vectorOfUInt8FromData:(NSData*)data;
+ (std::vector<std::map<std::string, std::string>>)arrayOfDictionnarisToVectorOfMap:(NSArray*)dictionaries;

@end

NS_ASSUME_NONNULL_END
