//
//  ELImageVideoCamera.h
//  liveDemo
//
//  Created by apple on 16/3/3.
//  Copyright © 2016年 changba. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "ELImageOutput.h"

@interface ELImageVideoCamera : ELImageOutput<AVCaptureVideoDataOutputSampleBufferDelegate>

- (id)initWithFPS:(int)fps;

- (void)startCapture;

- (void)stopCapture;

- (void)setFrameRate:(int)frameRate;

- (void)setFrameRate;
/**
 *  切换摄像头
 *
 *  @return 0:切到前置; 1:切到后置; -1:失败
 */
- (int)switchFrontBackCamera;

- (void)switchResolution;

@end
