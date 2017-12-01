//
//  ELImageView.m
//  liveDemo
//
//  Created by apple on 16/3/3.
//  Copyright © 2016年 changba. All rights reserved.
//

#import "ELImageView.h"
#import "ELImageDirectPassRenderer.h"
#import "ELImageOutput.h"

@implementation ELImageView
{
    ELImageTextureFrame*                    _inputFrameTexture;
    
    ELImageDirectPassRenderer*              _directPassRenderer;
    GLuint                                  _displayFramebuffer;
    GLuint                                  _renderbuffer;
    GLint                                   _backingWidth;
    GLint                                   _backingHeight;
}

+ (Class) layerClass
{
    return [CAEAGLLayer class];
}

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                        nil];

        runSyncOnVideoProcessingQueue(^{
            [ELImageContext useImageProcessingContext];
            if(![self createDisplayFramebuffer]){
                NSLog(@"create Dispaly Framebuffer failed...");
            }
            _directPassRenderer = [[ELImageDirectPassRenderer alloc] init];
            if (![_directPassRenderer prepareRender]) {
                NSLog(@"_directPassRenderer prepareRender failed...");
            }
        });
    }
    return self;
}
    
- (void)newFrameReadyAtTime:(CMTime)frameTime timimgInfo:(CMSampleTimingInfo)timimgInfo;
{
    glBindFramebuffer(GL_FRAMEBUFFER, _displayFramebuffer);
    [_directPassRenderer renderWithTextureId:[_inputFrameTexture texture] width:_backingWidth height:_backingHeight aspectRatio:TEXTURE_FRAME_ASPECT_RATIO];
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [[[ELImageContext sharedImageProcessingContext] context] presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)setInputTexture:(ELImageTextureFrame *)textureFrame;
{
    _inputFrameTexture = textureFrame;
}

- (BOOL) createDisplayFramebuffer;
{
    [ELImageContext useImageProcessingContext];
    BOOL ret = TRUE;
    glGenFramebuffers(1, &_displayFramebuffer);
    glGenRenderbuffers(1, &_renderbuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _displayFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [[[ELImageContext sharedImageProcessingContext] context] renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete framebuffer object %x", status);
        return FALSE;
    }
    
    GLenum glError = glGetError();
    if (GL_NO_ERROR != glError) {
        NSLog(@"failed to setup GL %x", glError);
        return FALSE;
    }
    return ret;
}

- (void)dealloc
{
    _directPassRenderer = nil;
    
    if (_displayFramebuffer) {
        glDeleteFramebuffers(1, &_displayFramebuffer);
        _displayFramebuffer = 0;
    }
    
    if (_renderbuffer) {
        glDeleteRenderbuffers(1, &_renderbuffer);
        _renderbuffer = 0;
    }
}

@end
