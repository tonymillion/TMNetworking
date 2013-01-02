//
//  TMMultipartBodyStream.h
//  Narrato
//
//  Created by Tony Million on 28/10/2012.
//  Copyright (c) 2012 Narrato. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "TMHTTPBodyPart.h"

@interface TMMultipartBodyStream : NSInputStream <NSStreamDelegate>

@property (nonatomic, assign) NSUInteger numberOfBytesInPacket;
@property (nonatomic, assign) NSTimeInterval delay;
@property (readonly) unsigned long long contentLength;
@property (readonly, getter = isEmpty) BOOL empty;

- (id)initWithStringEncoding:(NSStringEncoding)encoding;
- (void)setInitialAndFinalBoundaries;
- (void)appendHTTPBodyPart:(TMHTTPBodyPart *)bodyPart;

@end
