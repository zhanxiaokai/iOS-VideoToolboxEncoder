//
//  VideoEncoderRenderer.h
//  liveDemo
//
//  Created by apple on 16/3/2.
//  Copyright © 2016年 changba. All rights reserved.
//

#import "H264HwEncoderImpl.h"
#import <Foundation/Foundation.h>

@interface ELImageEncoderRenderer : NSObject
{
    CVPixelBufferRef                    renderTarget;
    CVOpenGLESTextureRef                renderTexture;
}

- (id) initWithWidth:(int)width height:(int)height fps:(float)fps maxBitRate:(int)maxBitRate avgBitRate:(int)avgBitRate encoderStatusDelegate:(id<ELVideoEncoderStatusDelegate>) encoderStatusDelegate;

- (void) settingMaxBitRate:(int)maxBitRate avgBitRate:(int)avgBitRate fps:(int)fps;

- (BOOL) prepareRender;

- (void)renderWithTextureId:(int) inputTex timimgInfo:(CMSampleTimingInfo)timimgInfo;

- (void) stopEncode;

@end
