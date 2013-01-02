//
//  TMHTTPRequest.h
//  narrato
//
//  Created by Tony Million on 16/12/2012.
//  Copyright (c) 2012 narrato. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TMHTTPRequest : NSObject

@property(readonly, nonatomic, strong) NSURLRequest         *request;
@property(readonly, nonatomic, strong) NSHTTPURLResponse    *response;

@property(readonly, nonatomic, strong) NSString             *contentType;

@property(strong, nonatomic)  dispatch_queue_t              dispatchQueue;


+(BOOL)hasAcceptableStatusCodeForStatus:(NSInteger)status;
+(NSSet *)acceptableJSONContentTypes;
+(NSSet *)acceptableImageContentTypes;
+(NSSet *)acceptableTextContentTypes;





-(id)initWithRequest:(NSURLRequest*)request;
-(void)setOperationQueue:(NSOperationQueue*)queue;

-(void)start;
-(void)cancel;

-(void)setSuccessBlock:(void (^)(TMHTTPRequest *request, id responseObject))success;
-(void)setFailureBlock:(void (^)(TMHTTPRequest *request, id responseObject, NSError * error))failure;
-(void)setProgressBlock:(void (^)(TMHTTPRequest *request, unsigned long long size, unsigned long long total))progress;


@end
