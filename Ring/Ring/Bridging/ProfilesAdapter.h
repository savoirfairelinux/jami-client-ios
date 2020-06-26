//
//  ProfilesAdapter.h
//  Ring
//
//  Created by kateryna on 2020-07-08.
//  Copyright © 2020 Savoir-faire Linux. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ProfilesAdapterDelegate;

@interface ProfilesAdapter : NSObject

@property (class, nonatomic, weak) id <ProfilesAdapterDelegate> delegate;

@end


