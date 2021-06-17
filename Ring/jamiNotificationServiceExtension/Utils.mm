//
//  Utils.m
//  jamiNotificationServiceExtension
//
//  Created by kateryna on 2021-06-08.
//  Copyright © 2021 Savoir-faire Linux. All rights reserved.
//

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

+ (NSMutableDictionary*)mapToDictionnary:
    (const std::map<std::string, std::string>&)map {
  NSMutableDictionary* resDictionnary = [NSMutableDictionary new];

  std::for_each(
      map.begin(), map.end(), ^(std::pair<std::string, std::string> keyValue) {
        id key = [NSString stringWithUTF8String:keyValue.first.c_str()];
        id value = [NSString stringWithUTF8String:keyValue.second.c_str()];
        [resDictionnary setObject:value forKey:key];
      });

  return resDictionnary;
}

+ (std::map<std::string, std::string>)dictionnaryToMap:(NSDictionary*)dict {
  std::map<std::string, std::string> resMap;
  for (id key in dict)
    resMap.insert(std::pair<std::string, std::string>(
        std::string([key UTF8String]),
        std::string([[dict objectForKey:key] UTF8String])));
  return resMap;
}

+ (std::vector<std::map<std::string, std::string>>)arrayOfDictionnarisToVectorOfMap:(NSArray*)dictionaries {
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
                      NSDictionary *dictionary = [Utils mapToDictionnary:map];
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
