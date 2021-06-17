//
//  Adapter.h
//  jamiNotificationServiceExtension
//
//  Created by kateryna on 2021-06-08.
//  Copyright © 2021 Savoir-faire Linux. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AdapterDelegate;

@interface Adapter : NSObject

@property (class, nonatomic, weak) id <AdapterDelegate> delegate;

- (BOOL)initDaemon;
- (BOOL)startDaemon;
- (void)pushNotificationReceived:(NSString *) from message:(NSDictionary*) data;

@end

NS_ASSUME_NONNULL_END
