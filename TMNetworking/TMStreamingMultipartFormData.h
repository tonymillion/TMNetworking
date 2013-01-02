//
//  TMStreamingMultipartFormData.h
//  Narrato
//
//  Created by Tony Million on 28/10/2012.
//  Copyright (c) 2012 Narrato. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "TMMultipartFormDataProtocol.h"

@interface TMStreamingMultipartFormData : NSObject <TMMultipartFormDataProtocol>

- (id)initWithURLRequest:(NSMutableURLRequest *)urlRequest
          stringEncoding:(NSStringEncoding)encoding;

- (NSMutableURLRequest *)requestByFinalizingMultipartFormData;

@end
