#import <Foundation/Foundation.h>

#import <map>
#import <string>
#import <vector>

NS_ASSUME_NONNULL_BEGIN

@interface Utils : NSObject

+ (NSArray*)vectorToArray:(const std::vector<std::string>&)vector;

@end

NS_ASSUME_NONNULL_END
