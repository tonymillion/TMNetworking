//
//  MSFoundation.h
//  NSData+Base64
//
//  Created by Sho.Maku on 11/03/31.
//  Copyright 2011 BraveSoft Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (MBBase64)

+(id)dataWithBase64EncodedString:(NSString *)string;     //  Padding '=' characters are optional. Whitespace is ignored.
-(NSString *)base64Encoding;

@end


