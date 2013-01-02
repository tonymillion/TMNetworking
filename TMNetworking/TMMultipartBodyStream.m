//
//  TMMultipartBodyStream.m
//  Narrato
//
//  Created by Tony Million on 28/10/2012.
//  Copyright (c) 2012 Narrato. All rights reserved.
//

#import "TMMultipartBodyStream.h"

#import "TMHTTPBodyPart.h"

@interface TMMultipartBodyStream ()
@property (nonatomic, assign) NSStreamStatus    streamStatus;
@property (nonatomic, strong) NSError           *streamError;

@property (nonatomic, assign) NSStringEncoding  stringEncoding;
@property (nonatomic, strong) NSMutableArray    *HTTPBodyParts;
@property (nonatomic, strong) NSEnumerator      *HTTPBodyPartEnumerator;
@property (nonatomic, strong) TMHTTPBodyPart    *currentHTTPBodyPart;
@end


@implementation TMMultipartBodyStream

- (id)initWithStringEncoding:(NSStringEncoding)encoding
{
    self = [super init];
    if (!self)
    {
        return nil;
    }
    
    self.stringEncoding = encoding;
    self.HTTPBodyParts = [NSMutableArray array];
    self.numberOfBytesInPacket = NSIntegerMax;
    
    return self;
}

- (void)setInitialAndFinalBoundaries
{
    if ([self.HTTPBodyParts count] > 0)
    {
        for (TMHTTPBodyPart *bodyPart in self.HTTPBodyParts)
        {
            bodyPart.hasInitialBoundary = NO;
            bodyPart.hasFinalBoundary = NO;
        }
        
        [[self.HTTPBodyParts objectAtIndex:0] setHasInitialBoundary:YES];
        [[self.HTTPBodyParts lastObject] setHasFinalBoundary:YES];
    }
}

- (void)appendHTTPBodyPart:(TMHTTPBodyPart *)bodyPart
{    
    [self.HTTPBodyParts addObject:bodyPart];
}

- (BOOL)isEmpty
{
    return [self.HTTPBodyParts count] == 0;
}

#pragma mark - NSInputStream

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)length
{
    if ([self streamStatus] == NSStreamStatusClosed)
    {
        return 0;
    }
    
    NSInteger bytesRead = 0;
    
    while ((NSUInteger)bytesRead < MIN(length, self.numberOfBytesInPacket))
    {
        if (!self.currentHTTPBodyPart || ![self.currentHTTPBodyPart hasBytesAvailable])
        {
            if (!(self.currentHTTPBodyPart = [self.HTTPBodyPartEnumerator nextObject]))
            {
                break;
            }
        }
        else
        {
            bytesRead += [self.currentHTTPBodyPart read:&buffer[bytesRead]
                                              maxLength:length - bytesRead];
            if (self.delay > 0.0f)
            {
                [NSThread sleepForTimeInterval:self.delay];
            }
        }
    }
    
    return bytesRead;
}

- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len
{
    return NO;
}

- (BOOL)hasBytesAvailable
{
    return [self streamStatus] == NSStreamStatusOpen;
}

#pragma mark - NSStream

- (void)open
{
    if (self.streamStatus == NSStreamStatusOpen)
    {
        return;
    }
    
    self.streamStatus = NSStreamStatusOpen;
    
    [self setInitialAndFinalBoundaries];
    self.HTTPBodyPartEnumerator = [self.HTTPBodyParts objectEnumerator];
}

- (void)close
{
    self.streamStatus = NSStreamStatusClosed;
}

- (id)propertyForKey:(NSString *)key {
    return nil;
}

- (BOOL)setProperty:(id)property forKey:(NSString *)key {
    return NO;
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop
                  forMode:(NSString *)mode
{}

- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop
                  forMode:(NSString *)mode
{}

- (unsigned long long)contentLength
{
    unsigned long long length = 0;
    for (TMHTTPBodyPart *bodyPart in self.HTTPBodyParts)
    {
        length += [bodyPart contentLength];
    }
    
    return length;
}

#pragma mark - Undocumented CFReadStream Bridged Methods

- (void)_scheduleInCFRunLoop:(CFRunLoopRef)aRunLoop
                     forMode:(CFStringRef)aMode
{}

- (void)_unscheduleFromCFRunLoop:(CFRunLoopRef)aRunLoop
                         forMode:(CFStringRef)aMode
{}

- (BOOL)_setCFClientFlags:(CFOptionFlags)inFlags
                 callback:(CFReadStreamClientCallBack)inCallback
                  context:(CFStreamClientContext *)inContext {
    return NO;
}

@end
