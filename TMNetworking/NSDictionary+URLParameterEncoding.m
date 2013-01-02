//
//  NSDictionary+URLParameterEncoding.m
//  narrato
//
//  Created by Tony Million on 16/12/2012.
//  Copyright (c) 2012 narrato. All rights reserved.
//

#import "NSDictionary+URLParameterEncoding.h"
#import "NSString+URLEncoding.h"

@implementation NSDictionary (URLParameterEncoding)

-(NSString*)URLParameters
{
    NSMutableArray * encodedPairs = [NSMutableArray array];
    
    for(NSString *key in self)
    {
        id temp = [self objectForKey:key];
        
        NSString * strParam;
        
        if([temp isKindOfClass:[NSString class]])
        {
            strParam = temp;
        }
        else
        {
            strParam = [NSString stringWithFormat:@"%@", temp];
        }
        
        NSString * kvp = [NSString stringWithFormat:@"%@=%@", [key URLEncodedString], [strParam URLEncodedString]];
        
        [encodedPairs addObject:kvp];
    }
    
    return [encodedPairs componentsJoinedByString:@"&"];
}

@end
