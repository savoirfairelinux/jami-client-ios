//
//  BlockchainAdapter.h
//  Ring
//
//  Created by Silbino Goncalves Matado on 17-04-04.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, LookupNameState) {
    Found = 0,
    InvalidName,
    Error
};

@protocol BlockchainAdapterDelegate;

@interface BlockchainAdapter : NSObject

@property (nonatomic, weak) id <BlockchainAdapterDelegate> delegate;

+ (instancetype)sharedManager;

- (void)lookupNameWithAccount:(NSString*)account nameserver:(NSString*)nameserver
                         name:(NSString*)name;

@end
