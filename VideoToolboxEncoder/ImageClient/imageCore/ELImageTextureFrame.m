//
//  GPUTextureFrame.m
//  liveDemo
//
//  Created by apple on 16/3/1.
//  Copyright © 2016年 changba. All rights reserved.
//

#import "ELImageTextureFrame.h"
#import "ELImageOutput.h"
#import "ELImageContext.h"

@implementation ELImageTextureFrame
{
    GLuint                              _framebuffer;
    GLuint                              _texture;
    GPUTextureFrameOptions              _textureOptions;
    CGSize                              _size;
    
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    CVPixelBufferRef renderTarget;
    CVOpenGLESTextureRef renderTexture;
    NSUInteger readLockCount;
#else
#endif
}

#pragma mark -
#pragma mark Usage

- (id)initWithSize:(CGSize)framebufferSize;
{
    GPUTextureFrameOptions defaultTextureOptions;
    defaultTextureOptions.minFilter = GL_LINEAR;
    defaultTextureOptions.magFilter = GL_LINEAR;
    defaultTextureOptions.wrapS = GL_CLAMP_TO_EDGE;
    defaultTextureOptions.wrapT = GL_CLAMP_TO_EDGE;
    defaultTextureOptions.internalFormat = GL_RGBA;
    defaultTextureOptions.format = GL_BGRA;
    defaultTextureOptions.type = GL_UNSIGNED_BYTE;
    
    if (!(self = [self initWithSize:framebufferSize textureOptions:defaultTextureOptions]))
    {
        return nil;
    }
    
    return self;
}

- (int) width;
{
    return _size.width;
}

- (int) height;
{
    return _size.height;
}

- (GLuint) texture;
{
    return _texture;
}

- (id)initWithSize:(CGSize)framebufferSize textureOptions:(GPUTextureFrameOptions)fboTextureOptions;
{
    if (!(self = [super init]))
    {
        return nil;
    }
    _size = framebufferSize;
    _textureOptions = fboTextureOptions;
    [self generateFramebuffer];
   
    return self;
}

- (void)activateFramebuffer;
{
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(0, 0, (int)_size.width, (int)_size.height);
}

- (void)dealloc
{
    [self destroyFramebuffer];
}

#pragma mark -
#pragma mark Internal

- (void)generateTexture;
{
    glActiveTexture(GL_TEXTURE1);
    glGenTextures(1, &_texture);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, _textureOptions.minFilter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, _textureOptions.magFilter);
    // This is necessary for non-power-of-two textures
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, _textureOptions.wrapS);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, _textureOptions.wrapT);
    
}

- (void)generateFramebuffer;
{
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    
    if ([ELImageContext supportsFastTextureUpload])
    {
        CVOpenGLESTextureCacheRef coreVideoTextureCache = [[ELImageContext sharedImageProcessingContext] coreVideoTextureCache];
        CFDictionaryRef empty; // empty value for attr value.
        CFMutableDictionaryRef attrs;
        empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks); // our empty IOSurface properties dictionary
        attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, empty);
        
        CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault, (int)_size.width, (int)_size.height, kCVPixelFormatType_32BGRA, attrs, &renderTarget);
        if (err)
        {
            NSLog(@"FBO size: %f, %f", _size.width, _size.height);
            NSAssert(NO, @"Error at CVPixelBufferCreate %d", err);
        }
        
        err = CVOpenGLESTextureCacheCreateTextureFromImage (kCFAllocatorDefault, coreVideoTextureCache, renderTarget,
                                                            NULL, // texture attributes
                                                            GL_TEXTURE_2D,
                                                            _textureOptions.internalFormat, // opengl format
                                                            (int)_size.width,
                                                            (int)_size.height,
                                                            _textureOptions.format, // native iOS format
                                                            _textureOptions.type,
                                                            0,
                                                            &renderTexture);
        if (err)
        {
            NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        }
        
        CFRelease(attrs);
        CFRelease(empty);
        
        glBindTexture(CVOpenGLESTextureGetTarget(renderTexture), CVOpenGLESTextureGetName(renderTexture));
        _texture = CVOpenGLESTextureGetName(renderTexture);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, _textureOptions.wrapS);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, _textureOptions.wrapT);
        
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(renderTexture), 0);
    }
    else
    {
        [self generateTexture];
        glBindTexture(GL_TEXTURE_2D, _texture);
        glTexImage2D(GL_TEXTURE_2D, 0, _textureOptions.internalFormat, (int)_size.width, (int)_size.height, 0, _textureOptions.format, _textureOptions.type, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _texture, 0);
    }
    glBindTexture(GL_TEXTURE_2D, 0);
}

- (GLubyte *)byteBuffer;
{
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    CVPixelBufferLockBaseAddress(renderTarget, 0);
    GLubyte * bufferBytes = CVPixelBufferGetBaseAddress(renderTarget);
    CVPixelBufferUnlockBaseAddress(renderTarget, 0);
    return bufferBytes;
#else
    return NULL; // TODO: do more with this on the non-texture-cache side
#endif
}

- (void)destroyFramebuffer;
{
    runSyncOnVideoProcessingQueue(^{
        
        if (_framebuffer)
        {
            glDeleteFramebuffers(1, &_framebuffer);
            _framebuffer = 0;
        }
        if ([ELImageContext supportsFastTextureUpload])
        {
            if (renderTarget)
            {
                CFRelease(renderTarget);
                renderTarget = NULL;
            }
            
            if (renderTexture)
            {
                CFRelease(renderTexture);
                renderTexture = NULL;
            }
        } else {
            glDeleteTextures(1, &_texture);
        }
    });
}

@end
