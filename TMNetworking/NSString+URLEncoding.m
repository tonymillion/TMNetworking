//
//  NSString+URLEncoding.m
//  narrato
//
//  Created by Tony Million on 16/12/2012.
//  Copyright (c) 2012 narrato. All rights reserved.
//

#import "NSString+URLEncoding.h"

@implementation NSString (URLEncoding)

-(NSString*)URLEncodedString
{
    return (__bridge_transfer NSString * ) CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                   (__bridge CFStringRef)self,
                                                                                   NULL,
                                                                                   (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                   kCFStringEncodingUTF8);}

@end
