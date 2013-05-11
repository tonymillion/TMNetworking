//
//  TMStreamingMultipartFormData.m
//  Narrato
//
//  Created by Tony Million on 28/10/2012.
//  Copyright (c) 2012 Narrato. All rights reserved.
//

#import "TMStreamingMultipartFormData.h"

#import "TMMultipartBodyStream.h"
#import "TMHTTPBodyPart.h"

static inline NSString * AFContentTypeForPathExtension(NSString *extension)
{
#ifdef __UTTYPE__
    NSString *UTI = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)extension, NULL);
    return (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)UTI, kUTTagClassMIMEType);
#else
    return @"application/octet-stream";
#endif
}

static NSString * const kAFMultipartFormBoundary = @"Boundary+0xAbCdEfGbOuNdArY";



@interface TMStreamingMultipartFormData ()
@property (readwrite, nonatomic, copy) NSMutableURLRequest *request;
@property (readwrite, nonatomic, strong) TMMultipartBodyStream *bodyStream;
@property (readwrite, nonatomic, assign) NSStringEncoding stringEncoding;
@end


@implementation TMStreamingMultipartFormData

@synthesize request = _request;
@synthesize bodyStream = _bodyStream;
@synthesize stringEncoding = _stringEncoding;

- (id)initWithURLRequest:(NSMutableURLRequest *)urlRequest
          stringEncoding:(NSStringEncoding)encoding
{
    self = [super init];
    if(self)
    {
        self.request        = urlRequest;
        self.stringEncoding = encoding;
        self.bodyStream     = [[TMMultipartBodyStream alloc] initWithStringEncoding:encoding];
    }
    
    return self;
}

- (BOOL)appendPartWithFileURL:(NSURL *)fileURL
                         name:(NSString *)name
                        error:(NSError * __autoreleasing *)error
{
    NSParameterAssert(fileURL);
    NSParameterAssert(name);
    
    if (![fileURL isFileURL])
    {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:NSLocalizedString(@"Expected URL to be a file URL", nil)
                                                             forKey:NSLocalizedFailureReasonErrorKey];
        if (error != NULL)
        {
            *error = [[NSError alloc] initWithDomain:@"kTMHTTPERROR"
                                                code:NSURLErrorBadURL
                                            userInfo:userInfo];
        }
        
        return NO;
    }
    else if ([fileURL checkResourceIsReachableAndReturnError:error] == NO)
    {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:NSLocalizedString(@"File URL not reachable.", nil)
                                                             forKey:NSLocalizedFailureReasonErrorKey];
        if (error != NULL)
        {
            *error = [[NSError alloc] initWithDomain:@"kTMHTTPERROR"
                                                code:NSURLErrorBadURL
                                            userInfo:userInfo];
        }
        
        return NO;
    }
    
    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
    
    [mutableHeaders setValue:[NSString stringWithFormat:@"form-data; name=\"%@\"; filename=\"%@\"", name, [fileURL lastPathComponent]]
                      forKey:@"Content-Disposition"];
    
    [mutableHeaders setValue:AFContentTypeForPathExtension([fileURL pathExtension])
                      forKey:@"Content-Type"];
    
    TMHTTPBodyPart *bodyPart    = [[TMHTTPBodyPart alloc] init];
    bodyPart.stringEncoding     = self.stringEncoding;
    bodyPart.headers            = mutableHeaders;
    bodyPart.inputStream        = [NSInputStream inputStreamWithURL:fileURL];
    
    NSDictionary *fileAttributes    = [[NSFileManager defaultManager] attributesOfItemAtPath:[fileURL path]
                                                                                       error:nil];
    bodyPart.bodyContentLength      = [[fileAttributes objectForKey:NSFileSize] unsignedLongLongValue];
    
    [self.bodyStream appendHTTPBodyPart:bodyPart];
    
    return YES;
}

- (void)appendPartWithFileData:(NSData *)data
                          name:(NSString *)name
                      fileName:(NSString *)fileName
                      mimeType:(NSString *)mimeType
{
    NSParameterAssert(name);
    NSParameterAssert(fileName);
    NSParameterAssert(mimeType);
    
    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
    
    [mutableHeaders setValue:[NSString stringWithFormat:@"form-data; name=\"%@\"; filename=\"%@\"", name, fileName]
                      forKey:@"Content-Disposition"];
    
    [mutableHeaders setValue:mimeType
                      forKey:@"Content-Type"];
    
    [self appendPartWithHeaders:mutableHeaders body:data];
}


- (void)appendPartWithFormData:(NSData *)data
                          name:(NSString *)name
{
    NSParameterAssert(name);
    
    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
    [mutableHeaders setValue:[NSString stringWithFormat:@"form-data; name=\"%@\"", name]
                      forKey:@"Content-Disposition"];
    
    [self appendPartWithHeaders:mutableHeaders
                           body:data];
}

//////////////////////////////////////////////////////////////////


- (void)appendPartWithInputStream:(NSInputStream *)iStream
                           length:(long long)streamLength
                             name:(NSString *)name
{
    NSParameterAssert(name);
    
    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
    [mutableHeaders setValue:[NSString stringWithFormat:@"form-data; name=\"%@\"", name]
                      forKey:@"Content-Disposition"];
    
    [self appendPartWithHeaders:mutableHeaders
                    inputStream:iStream
                         length:streamLength];
}

- (void)appendPartWithInputStream:(NSInputStream *)iStream
                           length:(long long)streamLength
                             name:(NSString *)name
                         fileName:(NSString *)fileName
                         mimeType:(NSString *)mimeType
{
    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
    
    [mutableHeaders setValue:[NSString stringWithFormat:@"form-data; name=\"%@\"; filename=\"%@\"", name, fileName]
                      forKey:@"Content-Disposition"];
    
    [mutableHeaders setValue:mimeType
                      forKey:@"Content-Type"];

    
    [self appendPartWithHeaders:mutableHeaders
                    inputStream:iStream
                         length:streamLength];
}




- (void)appendPartWithHeaders:(NSDictionary *)headers
                  inputStream:(NSInputStream *)iStream
                       length:(long long)streamLength
{
    TMHTTPBodyPart *bodyPart = [[TMHTTPBodyPart alloc] init];
    bodyPart.stringEncoding     = self.stringEncoding;
    bodyPart.headers            = headers;
    
    bodyPart.bodyContentLength  = streamLength;
    bodyPart.inputStream        = iStream;
    
    [self.bodyStream appendHTTPBodyPart:bodyPart];
}


- (void)appendPartWithHeaders:(NSDictionary *)headers
                         body:(NSData *)body
{
    TMHTTPBodyPart *bodyPart = [[TMHTTPBodyPart alloc] init];
    bodyPart.stringEncoding = self.stringEncoding;
    bodyPart.headers = headers;
    bodyPart.bodyContentLength = [body length];
    bodyPart.inputStream = [NSInputStream inputStreamWithData:body];
    
    [self.bodyStream appendHTTPBodyPart:bodyPart];
}

- (void)throttleBandwidthWithPacketSize:(NSUInteger)numberOfBytes
                                  delay:(NSTimeInterval)delay
{
    self.bodyStream.numberOfBytesInPacket = numberOfBytes;
    self.bodyStream.delay = delay;
}

- (NSMutableURLRequest *)requestByFinalizingMultipartFormData
{
    if ([self.bodyStream isEmpty])
    {
        return self.request;
    }
    
    // Reset the initial and final boundaries to ensure correct Content-Length
    [self.bodyStream setInitialAndFinalBoundaries];
    
    [self.request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", kAFMultipartFormBoundary] forHTTPHeaderField:@"Content-Type"];
    
    [self.request setValue:[NSString stringWithFormat:@"%llu", [self.bodyStream contentLength]]
        forHTTPHeaderField:@"Content-Length"];
    
    [self.request setHTTPBodyStream:self.bodyStream];

    return self.request;
}
@end
