//
//  ELImageVideoEncoder.h
//  liveDemo
//
//  Created by apple on 16/3/3.
//  Copyright © 2016年 changba. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ELImageContext.h"
#import "ELImageEncoderRenderer.h"

@interface ELImageVideoEncoder : NSObject<ELImageInput>

- (id) initWithFPS: (float) fps maxBitRate:(int)maxBitRate avgBitRate:(int)avgBitRate
      encoderWidth:(int)encoderWidth encoderHeight:(int)encoderHeight encoderStatusDelegate:(id<ELVideoEncoderStatusDelegate>) encoderStatusDelegate;

- (void) settingMaxBitRate:(int)maxBitRate avgBitRate:(int)avgBitRate fps:(int)fps;

- (void) stopEncode;

@end
