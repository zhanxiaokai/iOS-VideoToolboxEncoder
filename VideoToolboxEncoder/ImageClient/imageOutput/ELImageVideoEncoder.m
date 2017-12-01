//
//  ELImageVideoEncoder.m
//  liveDemo
//
//  Created by apple on 16/3/3.
//  Copyright © 2016年 changba. All rights reserved.
//

#import "ELImageVideoEncoder.h"

@implementation ELImageVideoEncoder
{
    ELImageTextureFrame*                    _inputFrameTexture;
    ELImageEncoderRenderer*                 _encoderRenderer;
    float                                   _fps;
    int                                     _maxBitRate;
    int                                     _avgBitRate;
    int                                     _encoderWidth;
    int                                     _encoderHeight;
    
    id<ELVideoEncoderStatusDelegate>        _encoderStatusDelegate;
}


- (id) initWithFPS: (float) fps maxBitRate:(int)maxBitRate avgBitRate:(int)avgBitRate
      encoderWidth:(int)encoderWidth encoderHeight:(int)encoderHeight encoderStatusDelegate:(id<ELVideoEncoderStatusDelegate>) encoderStatusDelegate;
{
    if (!(self = [super init]))
    {
        return nil;
    }
    _fps = fps;
    _maxBitRate = maxBitRate;
    _avgBitRate = avgBitRate;
    _encoderWidth = encoderWidth;
    _encoderHeight = encoderHeight;
    _encoderStatusDelegate = encoderStatusDelegate;
    return self;
}

- (void) settingMaxBitRate:(int)maxBitRate avgBitRate:(int)avgBitRate fps:(int)fps;
{
    [[self encoderRenderer] settingMaxBitRate:maxBitRate avgBitRate:avgBitRate fps:fps];
}

- (void) stopEncode
{
    if(_encoderRenderer){
        [_encoderRenderer stopEncode];
        _encoderRenderer = nil;
    }
}

- (void)newFrameReadyAtTime:(CMTime)frameTime timimgInfo:(CMSampleTimingInfo)timimgInfo;
{
    [[self encoderRenderer] renderWithTextureId:[_inputFrameTexture texture] timimgInfo:timimgInfo];
}

- (void)setInputTexture:(ELImageTextureFrame *)textureFrame;
{
    _inputFrameTexture = textureFrame;
}

- (ELImageEncoderRenderer*) encoderRenderer;
{
    if(nil == _encoderRenderer){
        _encoderRenderer = [[ELImageEncoderRenderer alloc] initWithWidth:_encoderWidth height:_encoderHeight fps:_fps maxBitRate:_maxBitRate avgBitRate:_avgBitRate encoderStatusDelegate:_encoderStatusDelegate];
        if (![_encoderRenderer prepareRender]){
            NSLog(@"VideoEncoderRenderer prepareRender failed...");
        }
    }
    return _encoderRenderer;
}

@end
