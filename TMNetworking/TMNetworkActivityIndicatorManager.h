//
//  TMNetworkActivityIndicatorManager.h
//  ZummZumm
//
//  Created by Tony Million on 26/05/2012.
//  Copyright (c) 2012 OmniTyke. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TMNetworkActivityIndicatorManager : NSObject

@property(assign) BOOL              enabled;

+(TMNetworkActivityIndicatorManager*)sharedManager;

-(void)incrementActivityCount;
-(void)decrementActivityCount;

-(void)resetActivityCount;

@end
