//
//  TMHTTPClient.h
//  narrato
//
//  Created by Tony Million on 16/12/2012.
//  Copyright (c) 2012 narrato. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "TMHTTPRequest.h"
#import "TMMultipartFormDataProtocol.h"
#import "TMStreamingMultipartFormData.h"

typedef enum {
    TMFormURLParameterEncoding,
    TMJSONParameterEncoding,
} TMHTTPClientParameterEncoding;


@interface TMHTTPClient : NSObject

@property(readonly, nonatomic, strong) NSURL                *baseURL;
@property(readonly, nonatomic) TMHTTPClientParameterEncoding  defaultParameterEncoding;

-(id)initWithBaseURL:(NSURL*)baseURL;

-(NSString *)valueForHeader:(NSString *)header;
-(void)setValue:(NSString *)value forHeader:(NSString *)header;

-(void)setBasicAuthorizationHeaderWithUsername:(NSString *)username password:(NSString *)password;
-(void)setBearerAuthorizationHeaderWithToken:(NSString *)token;
-(void)setAuthorizationHeaderWithType:(NSString*)type  token:(NSString *)token;
-(void)clearAuthorizationHeader;


-(void)setDefaultParameterEncoding:(TMHTTPClientParameterEncoding)defaultParameterEncoding;


-(NSMutableURLRequest *)requestWithMethod:(NSString *)method
                                     path:(NSString *)path
                               parameters:(NSDictionary *)parameters
                        parameterEncoding:(TMHTTPClientParameterEncoding)paramEncoding
                                    error:(NSError *__autoreleasing *)error;


- (NSMutableURLRequest *)multipartFormRequestWithMethod:(NSString *)method
                                                   path:(NSString *)path
                                             parameters:(NSDictionary *)parameters
                                      parameterEncoding:(TMHTTPClientParameterEncoding)paramEncoding
                              constructingBodyWithBlock:(void (^)(id<TMMultipartFormDataProtocol> formData))formdataBlock
                                                  error:(NSError *__autoreleasing *)error;

-(TMHTTPRequest *)HTTPRequestWithURLRequest:(NSURLRequest *)urlRequest
                                    success:(void (^)(TMHTTPRequest *request, id responseObject))success
                                    failure:(void (^)(TMHTTPRequest *request, id responseObject, NSError *error))failure;

-(void)startHTTPRequestOperation:(TMHTTPRequest *)request;
-(void)executeSynchronousRequest:(NSURLRequest*)request
                         success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *httpResponse, NSData * responseData, id responseObject))success
                         failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *httpResponse, NSData * responseData, id responseObject, NSError *error))failure;


-(TMHTTPRequest*)getPath:(NSString *)path
              parameters:(NSDictionary *)parameters
                 success:(void (^)(TMHTTPRequest *request, id responseObject))success
                 failure:(void (^)(TMHTTPRequest *request, id responseObject, NSError *error))failure;

- (TMHTTPRequest*)postPath:(NSString *)path
				parameters:(NSDictionary *)parameters
				   success:(void (^)(TMHTTPRequest *request, id responseObject))success
                   failure:(void (^)(TMHTTPRequest *request, id responseObject, NSError *error))failure;

- (TMHTTPRequest*)putPath:(NSString *)path
			   parameters:(NSDictionary *)parameters
				  success:(void (^)(TMHTTPRequest *request, id responseObject))success
                  failure:(void (^)(TMHTTPRequest *request, id responseObject, NSError *error))failure;

- (TMHTTPRequest*)deletePath:(NSString *)path
                  parameters:(NSDictionary *)parameters
                     success:(void (^)(TMHTTPRequest *request, id responseObject))success
                     failure:(void (^)(TMHTTPRequest *request, id responseObject, NSError *error))failure;

- (TMHTTPRequest*)patchPath:(NSString *)path
                 parameters:(NSDictionary *)parameters
                    success:(void (^)(TMHTTPRequest *request, id responseObject))success
                    failure:(void (^)(TMHTTPRequest *request, id responseObject, NSError *error))failure;

@end
