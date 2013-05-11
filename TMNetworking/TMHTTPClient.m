//
//  TMHTTPClient.m
//  narrato
//
//  Created by Tony Million on 16/12/2012.
//  Copyright (c) 2012 narrato. All rights reserved.
//

#import "TMHTTPClient.h"

#import "NSData+Base64.h"
#import "NSDictionary+URLParameterEncoding.h"

#import "TMHTTPRequest.h"

#import "TMNetworkActivityIndicatorManager.h"


@interface TMHTTPClient ()

@property(strong, nonatomic) NSMutableDictionary    *headers;
@property(strong, nonatomic) NSOperationQueue       *operationQueue;
@end


@implementation TMHTTPClient

-(id)initWithBaseURL:(NSURL*)baseURL
{
    self = [super init];
    
    if(self)
    {
        _baseURL = baseURL;
        _headers = [NSMutableDictionary dictionary];
        
        [self setValue:@"gzip" forHeader:@"Accept-Encoding"];
        
        [self setValue:[NSString stringWithFormat:@"%@/%@",
                        [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleIdentifierKey],
                        [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey]]
             forHeader:@"User-Agent"];
        
        _operationQueue = [[NSOperationQueue alloc] init];
    }
    
    return self;
}

#pragma mark -

-(NSString *)valueForHeader:(NSString *)header
{
	return [_headers valueForKey:header];
}

-(void)setValue:(NSString *)value forHeader:(NSString *)header
{
	[_headers setValue:value
                forKey:header];
}

-(void)setBasicAuthorizationHeaderWithUsername:(NSString *)username password:(NSString *)password
{
    // create an auth string, base64 encode it then pass it in the auth header (really???)
	NSString *basicAuthCredentials = [NSString stringWithFormat:@"%@:%@", username, password];
    NSString *base64String = [[basicAuthCredentials dataUsingEncoding:NSUTF8StringEncoding] base64Encoding];
    
    
    [self setValue:[NSString stringWithFormat:@"Basic %@", base64String]
         forHeader:@"Authorization"];
}

-(void)setBearerAuthorizationHeaderWithToken:(NSString *)token
{
    if(token == nil)
    {
        [self clearAuthorizationHeader];
        return;
    }
    
    [self setValue:[NSString stringWithFormat:@"Bearer %@", token]
         forHeader:@"Authorization"];
}

-(void)setAuthorizationHeaderWithType:(NSString*)type  token:(NSString *)token
{
    if(token == nil || type==nil)
    {
        [self clearAuthorizationHeader];
        return;
    }
    
    [self setValue:[NSString stringWithFormat:@"%@ %@", type, token]
         forHeader:@"Authorization"];
}


-(void)clearAuthorizationHeader
{
	[_headers removeObjectForKey:@"Authorization"];
}

-(void)setDefaultParameterEncoding:(TMHTTPClientParameterEncoding)defaultParameterEncoding
{
    _defaultParameterEncoding = defaultParameterEncoding;
    
    if(defaultParameterEncoding == TMJSONParameterEncoding)
    {
        [self setValue:@"application/json"
             forHeader:@"Accept"];
    }
    else
    {
        [self setValue:@"*/*"
             forHeader:@"Accept"];
        
    }
}

-(NSMutableURLRequest *)requestWithMethod:(NSString *)method
                                     path:(NSString *)path
                               bodyStream:(NSInputStream *)bodyStream
                                    error:(NSError *__autoreleasing *)error
{
    NSURL *url = [NSURL URLWithString:path
                        relativeToURL:self.baseURL];
    
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url
                                                                cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                            timeoutInterval:30];
    
    [request setHTTPMethod:method];
    
    [request setAllHTTPHeaderFields:_headers];
    [request setHTTPShouldUsePipelining:YES];
    
    [request setHTTPBodyStream:bodyStream];
    return request;
}

-(NSMutableURLRequest *)requestWithMethod:(NSString *)method
                                     path:(NSString *)path
                               parameters:(NSDictionary *)parameters
                        parameterEncoding:(TMHTTPClientParameterEncoding)paramEncoding
                                    error:(NSError *__autoreleasing *)error
{
    NSURL *url = [NSURL URLWithString:path
                        relativeToURL:self.baseURL];
    
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url
                                                                cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                            timeoutInterval:30];
    
    [request setHTTPMethod:method];
    
    [request setAllHTTPHeaderFields:_headers];
    [request setHTTPShouldUsePipelining:YES];
    
    if(parameters)
    {
        if([method isEqualToString:@"GET"] || [method isEqualToString:@"HEAD"] ) // || [method isEqualToString:@"DELETE"])
        {
            NSString * encodedparams = [parameters URLParameters];
            
            url = [NSURL URLWithString:[[url absoluteString] stringByAppendingFormat:[path rangeOfString:@"?"].location == NSNotFound ? @"?%@" : @"&%@", encodedparams]];
            [request setURL:url];
        }
        else
        {
            NSString *charset = (__bridge NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
            switch (paramEncoding)
            {
                case TMFormURLParameterEncoding:
                    {
                        [request setValue:[NSString stringWithFormat:@"application/x-www-form-urlencoded; charset=%@", charset]
                       forHTTPHeaderField:@"Content-Type"];
                        
                        NSString * encodedparams = [parameters URLParameters];
                        
                        [request setHTTPBody:[encodedparams dataUsingEncoding:NSUTF8StringEncoding]];
                    }
                    break;
                    
                case TMJSONParameterEncoding:
                    {
                        [request setValue:[NSString stringWithFormat:@"application/json; charset=%@", charset]
                       forHTTPHeaderField:@"Content-Type"];
                        
                        NSData * body = [NSJSONSerialization dataWithJSONObject:parameters
                                                                        options:0
                                                                          error:error];
                        
                        if(!body)
                            return nil;
                        
                        [request setHTTPBody:body];
                    }
                    break;
            }
        }
    }
    
    return request;
}


- (NSMutableURLRequest *)multipartFormRequestWithMethod:(NSString *)method
                                                   path:(NSString *)path
                                             parameters:(NSDictionary *)parameters
                                          paramPartName:(NSString*)paramPartName
                                      parameterEncoding:(TMHTTPClientParameterEncoding)paramEncoding
                              constructingBodyWithBlock:(void (^)(id<TMMultipartFormDataProtocol> formData))formdataBlock
                                                  error:(NSError *__autoreleasing *)error
{
    NSMutableURLRequest *request = [self requestWithMethod:method
                                                      path:path
                                                parameters:nil
                                         parameterEncoding:paramEncoding
                                                     error:error];
    
    __block TMStreamingMultipartFormData *formData = [[TMStreamingMultipartFormData alloc] initWithURLRequest:request
                                                                                               stringEncoding:NSUTF8StringEncoding];
    
    if(parameters)
    {
        switch (paramEncoding)
        {
            case TMFormURLParameterEncoding:
            {
                for (NSString * key in parameters) {
                    id value = parameters[key];
                    
                    NSString * valueString = [NSString stringWithFormat:@"%@", value];
                    
                    
                    NSString * dispositionString = [NSString stringWithFormat:@"form-data; name=\"%@\"", key];
                    
                    [formData appendPartWithHeaders:@{
                     @"Content-Disposition": dispositionString,
                     @"Content-Type": @"multipart/form-data"}
                                               body:[valueString dataUsingEncoding:NSUTF8StringEncoding]];
                }
                /*
                L.append('--' + BOUNDARY)
                L.append('Content-Disposition: form-data; name="%s"' % key)
                L.append('')
                L.append(value)
                
                NSString * encodedparams = [parameters URLParameters];
                
                [formData appendPartWithHeaders:
                                           body:[encodedparams dataUsingEncoding:NSUTF8StringEncoding]];
                 */
            }
                break;
                
            case TMJSONParameterEncoding:
            {
                NSData * body = [NSJSONSerialization dataWithJSONObject:parameters
                                                                options:0
                                                                  error:error];
                
                if(body)
                {
                    [formData appendPartWithFileData:body
                                                name:paramPartName
                                            fileName:paramPartName
                                            mimeType:@"application/json"];
                }
                
            }
                break;
        }
    }
    
    if(formdataBlock)
    {
        formdataBlock(formData);
    }
    
    return [formData requestByFinalizingMultipartFormData];
}

//////////////////////////////////////////////////////////////////
//
//      Create TMHTTP Requests out of this stuff
//
//

-(TMHTTPRequest *)HTTPRequestWithURLRequest:(NSURLRequest *)urlRequest
                                    success:(void (^)(TMHTTPRequest *request, id responseObject))success
                                    failure:(void (^)(TMHTTPRequest *request, id responseObject, NSError *error))failure
{
    TMHTTPRequest *operation = nil;
    
    operation = [[TMHTTPRequest alloc] initWithRequest:urlRequest];
    
    [operation setSuccessBlock:success];
    [operation setFailureBlock:failure];
    
    return operation;
}


-(void)startHTTPRequestOperation:(TMHTTPRequest *)request
{
	[request setOperationQueue:self.operationQueue];
	[request start];
}


//////////////////////////////////////////////////////////////////
//
//  Starts a synchronous request based on the passed in
//  based on the request passed in
//
//  this *WILL* block the thread which is it called on
//

-(void)determineSuccessAndSend:(id)object
                         error:(NSError*)error
                   httpRequest:(NSURLRequest*)request
                  httpResponse:(NSHTTPURLResponse*)response
                       success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *httpResponse, NSData * responseData, id responseObject))success
                       failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *httpResponse, NSData * responseData, id responseObject, NSError *error))failure

{
    if(object)
    {
        // if we get here we got a response, but we still might fail if status != 200,299
        
        if( [TMHTTPRequest hasAcceptableStatusCodeForStatus:response.statusCode] )
        {
            success(request, response, nil, object);
        }
        else
        {
            // yep it was a 300-600 status code!
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            [userInfo setValue:[request URL]
                        forKey:NSURLErrorFailingURLErrorKey];
            
            [userInfo setValue:[NSString stringWithFormat:NSLocalizedString(@"HTTP Status: %d", @""), response.statusCode]
                        forKey:NSLocalizedDescriptionKey];
            
            failure(request, response, nil, object, [[NSError alloc] initWithDomain:NSURLErrorDomain
                                                                               code:NSURLErrorBadServerResponse
                                                                           userInfo:userInfo]);
        }
    }
    else
    {
        // ITS A BIG FAIL
        failure(request, response, nil, object, error);
    }
}

-(BOOL)executeSynchronousRequest:(NSURLRequest*)request
                         success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *httpResponse, NSData * responseData, id responseObject))success
                         failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *httpResponse, NSData * responseData, id responseObject, NSError *error))failure
{
    NSHTTPURLResponse	*httpResponse;
    NSError				*reqError;
    
    
    __block UIBackgroundTaskIdentifier _networkTaskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if(_networkTaskID != UIBackgroundTaskInvalid)
        {
            [[UIApplication sharedApplication] endBackgroundTask:_networkTaskID];
            _networkTaskID = UIBackgroundTaskInvalid;
        }
    }];
    
    
    //submit the request synchronously
    [[TMNetworkActivityIndicatorManager sharedManager] incrementActivityCount];
    
    NSData * resultData = [NSURLConnection sendSynchronousRequest:request
                                                returningResponse:&httpResponse
                                                            error:&reqError];
    
    
    NSString *_contentType;
    _contentType = [httpResponse MIMEType];
    if(!_contentType)
    {
        _contentType = @"application/octet-stream";
    }
    
    if(reqError)
    {
        [self determineSuccessAndSend:nil
                                error:reqError
                          httpRequest:request
                         httpResponse:httpResponse
                              success:success
                              failure:failure];
    }
    else
    {
        
        //if success then delete recipt from local!
        if([[TMHTTPRequest acceptableJSONContentTypes] containsObject:_contentType])
        {
            // this was JSON
            NSError * err;
            id jsonObject = [NSJSONSerialization JSONObjectWithData:resultData
                                                            options:0
                                                              error:&err];
            
            if(jsonObject)
            {
                [self determineSuccessAndSend:jsonObject
                                        error:nil
                                  httpRequest:request
                                 httpResponse:httpResponse
                                      success:success
                                      failure:failure];
            }
            else
            {
                [self determineSuccessAndSend:nil
                                        error:err
                                  httpRequest:request
                                 httpResponse:httpResponse
                                      success:success
                                      failure:failure];
                
            }
        }
        else if([[TMHTTPRequest acceptableImageContentTypes] containsObject:_contentType])
        {
            // this was AN IMAGE
            //note we DO NOT DECODE THE IMAGE HERE - thats a client-side thing
            
            [self determineSuccessAndSend:resultData
                                    error:nil
                              httpRequest:request
                             httpResponse:httpResponse
                                  success:success
                                  failure:failure];
            
        }
        else if([[TMHTTPRequest acceptableTextContentTypes] containsObject:_contentType])
        {
            // this was either text or something else!
            [self determineSuccessAndSend:[[NSString alloc] initWithData:resultData
                                                                encoding:NSUTF8StringEncoding]
                                    error:nil
                              httpRequest:request
                             httpResponse:httpResponse
                                  success:success
                                  failure:failure];
            
        }
        else
        {
            // this is BINARY DATA
            [self determineSuccessAndSend:resultData
                                    error:nil
                              httpRequest:request
                             httpResponse:httpResponse
                                  success:success
                                  failure:failure];
        }
    }
    
    
    [[TMNetworkActivityIndicatorManager sharedManager] decrementActivityCount];
    
    
    // end the background task
    if(_networkTaskID != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:_networkTaskID];
        _networkTaskID = UIBackgroundTaskInvalid;
    }
    
    return YES;
}



//////////////////////////////////////////////////////////////////
//
//  CONVENIENCE FUNCTIONS
//
//  Basic stuff to cover get/post/put/delete


-(TMHTTPRequest*)getPath:(NSString *)path
              parameters:(NSDictionary *)parameters
                 success:(void (^)(TMHTTPRequest *request, id responseObject))success
                 failure:(void (^)(TMHTTPRequest *request, id responseObject, NSError *error))failure
{
	NSURLRequest *URLrequest = [self requestWithMethod:@"GET"
                                                  path:path
                                            parameters:parameters
                                     parameterEncoding:_defaultParameterEncoding
                                                 error:nil];
    
    if(!URLrequest)
        return nil;
    
    TMHTTPRequest *httprequest = [self HTTPRequestWithURLRequest:URLrequest
                                                         success:success
                                                         failure:failure];
    [self startHTTPRequestOperation:httprequest];
    
    return httprequest;
}

- (TMHTTPRequest*)postPath:(NSString *)path
				parameters:(NSDictionary *)parameters
				   success:(void (^)(TMHTTPRequest *request, id responseObject))success
                   failure:(void (^)(TMHTTPRequest *request, id responseObject, NSError *error))failure
{
	NSURLRequest *URLrequest = [self requestWithMethod:@"POST"
                                                  path:path
                                            parameters:parameters
                                     parameterEncoding:_defaultParameterEncoding
                                                 error:nil];
    if(!URLrequest)
        return nil;
    
	TMHTTPRequest *operation = [self HTTPRequestWithURLRequest:URLrequest
                                                       success:success
                                                       failure:failure];
    [self startHTTPRequestOperation:operation];
    
    return operation;
}

- (TMHTTPRequest*)postPath:(NSString *)path
				parameters:(NSDictionary *)parameters
         parameterEncoding:(TMHTTPClientParameterEncoding)paramEncoding
				   success:(void (^)(TMHTTPRequest *request, id responseObject))success
                   failure:(void (^)(TMHTTPRequest *request, id responseObject, NSError *error))failure
{
	NSURLRequest *URLrequest = [self requestWithMethod:@"POST"
                                                  path:path
                                            parameters:parameters
                                     parameterEncoding:paramEncoding
                                                 error:nil];
    if(!URLrequest)
        return nil;
    
	TMHTTPRequest *operation = [self HTTPRequestWithURLRequest:URLrequest
                                                       success:success
                                                       failure:failure];
    [self startHTTPRequestOperation:operation];
    
    return operation;
}

- (TMHTTPRequest*)putPath:(NSString *)path
			   parameters:(NSDictionary *)parameters
				  success:(void (^)(TMHTTPRequest *request, id responseObject))success
                  failure:(void (^)(TMHTTPRequest *request, id responseObject, NSError *error))failure
{
	NSURLRequest *URLrequest = [self requestWithMethod:@"PUT"
                                                  path:path
                                            parameters:parameters
                                     parameterEncoding:_defaultParameterEncoding
                                                 error:nil];
    if(!URLrequest)
        return nil;
    
    
	TMHTTPRequest *operation = [self HTTPRequestWithURLRequest:URLrequest
                                                       success:success
                                                       failure:failure];
    [self startHTTPRequestOperation:operation];
    
    return operation;
}

- (TMHTTPRequest*)deletePath:(NSString *)path
                  parameters:(NSDictionary *)parameters
                     success:(void (^)(TMHTTPRequest *request, id responseObject))success
                     failure:(void (^)(TMHTTPRequest *request, id responseObject, NSError *error))failure
{
    NSURLRequest *URLrequest = [self requestWithMethod:@"DELETE"
                                                  path:path
                                            parameters:parameters
                                     parameterEncoding:_defaultParameterEncoding
                                                 error:nil];
    if(!URLrequest)
        return nil;
    
    TMHTTPRequest *operation = [self HTTPRequestWithURLRequest:URLrequest
                                                       success:success
                                                       failure:failure];
    [self startHTTPRequestOperation:operation];
    
    return operation;
}

- (TMHTTPRequest*)patchPath:(NSString *)path
                 parameters:(NSDictionary *)parameters
                    success:(void (^)(TMHTTPRequest *request, id responseObject))success
                    failure:(void (^)(TMHTTPRequest *request, id responseObject, NSError *error))failure
{
    NSURLRequest *URLrequest = [self requestWithMethod:@"PATCH"
                                                  path:path
                                            parameters:parameters
                                     parameterEncoding:_defaultParameterEncoding
                                                 error:nil];
    if(!URLrequest)
        return nil;
    
    TMHTTPRequest *operation = [self HTTPRequestWithURLRequest:URLrequest
                                                       success:success
                                                       failure:failure];
    [self startHTTPRequestOperation:operation];
    
    return operation;
}






-(BOOL)syncGetPath:(NSString *)path
        parameters:(NSDictionary *)parameters
           success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *httpResponse, NSData * responseData, id responseObject))success
           failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *httpResponse, NSData * responseData, id responseObject, NSError *error))failure
{
    NSURLRequest *URLrequest = [self requestWithMethod:@"GET"
                                                  path:path
                                            parameters:parameters
                                     parameterEncoding:_defaultParameterEncoding
                                                 error:nil];
    
    if(!URLrequest)
        return NO;
    
    return [self executeSynchronousRequest:URLrequest
                                   success:success
                                   failure:failure];
}

-(BOOL)syncPostPath:(NSString *)path
         parameters:(NSDictionary *)parameters
            success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *httpResponse, NSData * responseData, id responseObject))success
            failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *httpResponse, NSData * responseData, id responseObject, NSError *error))failure
{
	NSURLRequest *URLrequest = [self requestWithMethod:@"POST"
                                                  path:path
                                            parameters:parameters
                                     parameterEncoding:_defaultParameterEncoding
                                                 error:nil];
    if(!URLrequest)
        return NO;
    
    return [self executeSynchronousRequest:URLrequest
                                   success:success
                                   failure:failure];
}

-(BOOL)syncPutPath:(NSString *)path
        parameters:(NSDictionary *)parameters
           success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *httpResponse, NSData * responseData, id responseObject))success
           failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *httpResponse, NSData * responseData, id responseObject, NSError *error))failure
{
	NSURLRequest *URLrequest = [self requestWithMethod:@"PUT"
                                                  path:path
                                            parameters:parameters
                                     parameterEncoding:_defaultParameterEncoding
                                                 error:nil];
    if(!URLrequest)
        return NO;
    
    return [self executeSynchronousRequest:URLrequest
                                   success:success
                                   failure:failure];
}

-(BOOL)syncPatchPath:(NSString *)path
          parameters:(NSDictionary *)parameters
             success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *httpResponse, NSData * responseData, id responseObject))success
             failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *httpResponse, NSData * responseData, id responseObject, NSError *error))failure
{
	NSURLRequest *URLrequest = [self requestWithMethod:@"PATCH"
                                                  path:path
                                            parameters:parameters
                                     parameterEncoding:_defaultParameterEncoding
                                                 error:nil];
    if(!URLrequest)
        return NO;
    
    return [self executeSynchronousRequest:URLrequest
                                   success:success
                                   failure:failure];
    
}


-(BOOL)syncDeletePath:(NSString *)path
           parameters:(NSDictionary *)parameters
              success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *httpResponse, NSData * responseData, id responseObject))success
              failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *httpResponse, NSData * responseData, id responseObject, NSError *error))failure
{
    NSURLRequest *URLrequest = [self requestWithMethod:@"DELETE"
                                                  path:path
                                            parameters:parameters
                                     parameterEncoding:_defaultParameterEncoding
                                                 error:nil];
    if(!URLrequest)
        return NO;
    
    return [self executeSynchronousRequest:URLrequest
                                   success:success
                                   failure:failure];
}


@end
