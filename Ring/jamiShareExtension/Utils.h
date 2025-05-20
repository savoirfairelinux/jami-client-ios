#import <Foundation/Foundation.h>

#import <map>
#import <string>
#import <vector>

NS_ASSUME_NONNULL_BEGIN

@interface Utils : NSObject

+ (NSArray*)vectorToArray:(const std::vector<std::string>&)vector;
+ (NSMutableDictionary*)mapToDictionnaryWithInt:(const std::map<std::string, int32_t>&)map;
+ (NSArray*)vectorOfMapsToArray:(const std::vector<std::map<std::string, std::string>>&)vectorOfMaps;
+ (NSMutableDictionary*)mapToDictionnary:
    (const std::map<std::string, std::string>&)map;

@end

NS_ASSUME_NONNULL_END
