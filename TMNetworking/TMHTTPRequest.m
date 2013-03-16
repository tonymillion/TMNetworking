//
//  TMHTTPRequest.m
//  narrato
//
//  Created by Tony Million on 16/12/2012.
//  Copyright (c) 2012 narrato. All rights reserved.
//

#import "TMHTTPRequest.h"

#import "TMNetworkActivityIndicatorManager.h"

typedef void (^TMHTTPSuccessBlock)(TMHTTPRequest *request, id responseObject);
typedef void (^TMHTTPFailureBlock)(TMHTTPRequest *request, id responseObject, NSError * error);

typedef void (^TMHTTPProgressBlock)(TMHTTPRequest *request, unsigned long long size, unsigned long long total);


@interface TMHTTPRequest() <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property(strong) NSURLConnection       *urlConnection;
@property(strong) NSMutableData         *downloadedData;

@property(copy) TMHTTPSuccessBlock      internalSuccessBlock;
@property(copy) TMHTTPFailureBlock      internalFailureBlock;
@property(copy) TMHTTPProgressBlock     internalProgressBlock;

@property(strong) NSError               *connectionError;

@property(assign) UIBackgroundTaskIdentifier    networkTaskID;

@end


@implementation TMHTTPRequest

+(BOOL)hasAcceptableStatusCodeForStatus:(NSInteger)status
{
    return [[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)] containsIndex:status];
}

+(NSSet *)acceptableJSONContentTypes
{
    return [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", nil];
}

+(NSSet *)acceptableImageContentTypes
{
    return [NSSet setWithObjects:@"image/tiff", @"image/jpeg", @"image/gif", @"image/png", @"image/ico", @"image/x-icon", @"image/bmp", @"image/x-bmp", @"image/x-xbitmap", @"image/x-win-bitmap", nil];
}

+(NSSet *)acceptableTextContentTypes
{
    return [NSSet setWithObjects:@"text/plain", @"text/html", nil];
}


-(id)initWithRequest:(NSURLRequest*)request
{
    self = [super init];
    if(self)
    {
        _dispatchQueue  = dispatch_get_main_queue();
        _request        = request;
        
        _urlConnection  = [[NSURLConnection alloc] initWithRequest:_request
                                                          delegate:self
                                                  startImmediately:NO];
    }
    return self;
}

-(void)setOperationQueue:(NSOperationQueue*)queue
{
    [_urlConnection setDelegateQueue:queue];
}

-(void)start
{
    [[TMNetworkActivityIndicatorManager sharedManager] incrementActivityCount];

    _networkTaskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if(_networkTaskID != UIBackgroundTaskInvalid)
        {
            [[UIApplication sharedApplication] endBackgroundTask:_networkTaskID];
            _networkTaskID = UIBackgroundTaskInvalid;
        }
    }];
    
    [_urlConnection start];
}

-(void)cancel
{
    [_urlConnection cancel];
    
    [self connection:_urlConnection
    didFailWithError: [NSError errorWithDomain:NSURLErrorDomain
                                          code:NSURLErrorCancelled
                                      userInfo:nil]];
}


-(void)setSuccessBlock:(void (^)(TMHTTPRequest *, id))success
{
    _internalSuccessBlock = success;
}

-(void)setFailureBlock:(void (^)(TMHTTPRequest *, id, NSError *))failure
{
    _internalFailureBlock = failure;
}

-(void)setProgressBlock:(void (^)(TMHTTPRequest *request, unsigned long long size, unsigned long long total))progress
{
    _internalProgressBlock = progress;
}



#pragma mark - NSURLConnectionDataDelegate stuff

- (NSURLRequest *)connection:(NSURLConnection *)connection
             willSendRequest:(NSURLRequest *)request
            redirectResponse:(NSURLResponse *)response
{
    return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    //When called alloc a new data to write into
    _response = (NSHTTPURLResponse*)response;

    _contentType = [_response MIMEType];
    if(!_contentType)
    {
        _contentType = @"application/octet-stream";
    }

    //may be called multiple times so we DISCARD what we already had if necessary and start over
    // (dont ask me)
    _downloadedData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // append to a data
    [_downloadedData appendData:data];
    
    if(self.internalProgressBlock)
    {
        dispatch_async(_dispatchQueue, ^{
            self.internalProgressBlock(self, _downloadedData.length, _response.expectedContentLength);
        });
    }
}

- (void)connection:(NSURLConnection *)connection
   didSendBodyData:(NSInteger)bytesWritten
 totalBytesWritten:(NSInteger)totalBytesWritten
totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if([[TMHTTPRequest acceptableJSONContentTypes] containsObject:_contentType])
    {
        // this was JSON
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSError * err;
            id jsonObject = [NSJSONSerialization JSONObjectWithData:_downloadedData
                                                            options:0
                                                              error:&err];
            
            if(jsonObject)
            {
                dispatch_async(_dispatchQueue, ^{
                    [self determineSuccessAndSend:jsonObject error:nil];
                });
            }
            else
            {
                dispatch_async(_dispatchQueue, ^{
                    [self determineSuccessAndSend:nil
                                            error:err];
                });
            }
        });
    }
    else if([[TMHTTPRequest acceptableImageContentTypes] containsObject:_contentType])
    {
        // this was AN IMAGE
        //note we DO NOT DECODE THE IMAGE HERE - thats a client-side thing
        
        dispatch_async(_dispatchQueue, ^{
            [self determineSuccessAndSend:_downloadedData error:nil];
        });
    }
    else if([[TMHTTPRequest acceptableTextContentTypes] containsObject:_contentType])
    {
        // this was either text or something else!
        dispatch_async(_dispatchQueue, ^{
            [self determineSuccessAndSend:[[NSString alloc] initWithData:_downloadedData
                                                                encoding:NSUTF8StringEncoding]
                                    error:nil];
        });
    }
    else
    {
        // this is BINARY DATA
        dispatch_async(_dispatchQueue, ^{
            [self determineSuccessAndSend:_downloadedData
                                    error:nil];
        });
    }
}

#pragma mark - NSURLConnectionDelegate stuff

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    dispatch_async(_dispatchQueue, ^{
        [self determineSuccessAndSend:nil
                                error:error];
    });
}

-(void)determineSuccessAndSend:(id)object error:(NSError*)error
{
    if(object)
    {
        // if we get here we got a response, but we still might fail if status != 200,299
        
        if( [TMHTTPRequest hasAcceptableStatusCodeForStatus:_response.statusCode] )
        {
            if(_internalSuccessBlock)
            {
                _internalSuccessBlock(self, object);
            }
        }
        else
        {
            // yep it was a 300-600 status code!
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            [userInfo setValue:[self.request URL]
                        forKey:NSURLErrorFailingURLErrorKey];
            
            [userInfo setValue:[NSString stringWithFormat:NSLocalizedString(@"HTTP Status: %d", @""), _response.statusCode]
                        forKey:NSLocalizedDescriptionKey];
            
            [userInfo setValue:object
                        forKey:@"object"];

            if(_internalFailureBlock)
            {
                _internalFailureBlock(self, object, [[NSError alloc] initWithDomain:NSURLErrorDomain
                                                                               code:NSURLErrorBadServerResponse
                                                                           userInfo:userInfo]);
            }
        }
    }
    else
    {
        // ITS A BIG FAIL
        if(_internalFailureBlock)
        {
            _internalFailureBlock(self, object, error);
        }

    }

    // end the background task
    if(_networkTaskID != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:_networkTaskID];
        _networkTaskID = UIBackgroundTaskInvalid;
    }
    
    [[TMNetworkActivityIndicatorManager sharedManager] decrementActivityCount];

}

@end
