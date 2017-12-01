//
//  ELImageVideoScheduler.h
//  liveDemo
//
//  Created by apple on 16/3/4.
//  Copyright © 2016年 changba. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ELImageVideoEncoder.h"

@interface ELImageVideoScheduler : NSObject

/**
 *  默认开启自动对比度
 */
- (instancetype) initWithFrame:(CGRect) bounds videoFrameRate:(int)frameRate;
- (instancetype) initWithFrame:(CGRect) bounds videoFrameRate:(int)frameRate disableAutoContrast:(BOOL)disableAutoContrast;
- (UIView*) previewView;

- (void) startPreview;

- (void) stopPreview;

- (int) switchFrontBackCamera;

- (void) startEncodeWithFPS:(float)fps maxBitRate:(int)maxBitRate avgBitRate:(int)avgBitRate
               encoderWidth:(int)encoderWidth encoderHeight:(int)encoderHeight encoderStatusDelegate:(id<ELVideoEncoderStatusDelegate>)encoderStatusDelegate;

- (void) stopEncode;
@end
