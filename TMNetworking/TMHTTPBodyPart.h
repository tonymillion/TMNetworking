//
//  TMHTTPBodyPart.h
//  Narrato
//
//  Created by Tony Million on 28/10/2012.
//  Copyright (c) 2012 Narrato. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TMHTTPBodyPart : NSObject

@property (nonatomic, assign) NSStringEncoding stringEncoding;
@property (nonatomic, strong) NSDictionary *headers;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, assign) unsigned long long bodyContentLength;

@property (nonatomic, assign) BOOL hasInitialBoundary;
@property (nonatomic, assign) BOOL hasFinalBoundary;

@property (readonly, getter = hasBytesAvailable) BOOL bytesAvailable;
@property (readonly) unsigned long long contentLength;

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)length;

@end
