//
//  VideoEncoderRenderer.m
//  liveDemo
//
//  Created by apple on 16/3/2.
//  Copyright © 2016年 changba. All rights reserved.
//

#import "ELImageOutput.h"
#import "ELImageEncoderRenderer.h"
#import "ELImageProgram.h"
#import "H264HwEncoderHandler.h"
#import "ELImageContext.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

NSString *const videoEncodeVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
 }
 );

NSString *const videoEncodeFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
 }
 );

NSString *const videoEncodeColorSwizzlingFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate).bgra;
 }
 );

@implementation ELImageEncoderRenderer
{
    GLuint                              _encodeFramebuffer;
    GLuint                              _encodeRenderbuffer;
    uint8_t*                            _renderTargetBuf;
    
    int                                 _width;
    int                                 _height;
    float                               _fps;
    int                                 _maxBitRate;
    int                                 _avgBitRate;
    
    ELImageProgram*                     _program;
    GLint                               displayPositionAttribute;
    GLint                               displayTextureCoordinateAttribute;
    GLint                               displayInputTextureUniform;
    
    H264HwEncoderImpl*                  _h264Encoder;
    H264HwEncoderHandler*               _H264HwEncoderHandler;
    id<ELVideoEncoderStatusDelegate>   _encoderStatusDelegate;
    
    /** 把编码放到一个单独的线程中去 **/
    ELImageContext *                   _encoderContext;
}


- (id) initWithWidth:(int)width height:(int)height fps:(float)fps maxBitRate:(int)maxBitRate avgBitRate:(int)avgBitRate encoderStatusDelegate:(id<ELVideoEncoderStatusDelegate>) encoderStatusDelegate;
{
    self = [super init];
    if (self) {
        _width = width;
        _height = height;
        _encoderStatusDelegate = encoderStatusDelegate;
        _fps = fps;
        _maxBitRate = maxBitRate;
        _avgBitRate = avgBitRate;
        [self h264Encoder];
    }
    return self;
}
- (void) settingMaxBitRate:(int)maxBitRate avgBitRate:(int)avgBitRate fps:(int)fps;
{
    if(_h264Encoder)
    {
        [_h264Encoder settingMaxBitRate:maxBitRate avgBitRate:avgBitRate fps:fps];
    }
}

- (BOOL) prepareRender;
{
    BOOL ret = TRUE;
    
    _encoderContext = [[ELImageContext alloc] init];
    [_encoderContext useSharegroup:[[[ELImageContext sharedImageProcessingContext] context] sharegroup]];
    
    NSLog(@"Create _encoderContext Success...");
    dispatch_sync([_encoderContext contextQueue], ^{
        [_encoderContext useAsCurrentContext];
        if([ELImageContext supportsFastTextureUpload]){
            _program = [[ELImageProgram alloc] initWithVertexShaderString:videoEncodeVertexShaderString fragmentShaderString:videoEncodeFragmentShaderString];
        } else{
            _program = [[ELImageProgram alloc] initWithVertexShaderString:videoEncodeVertexShaderString fragmentShaderString:videoEncodeColorSwizzlingFragmentShaderString];
        }
        if(_program){
            [_program addAttribute:@"position"];
            [_program addAttribute:@"inputTextureCoordinate"];
            if([_program link]){
                displayPositionAttribute = [_program attributeIndex:@"position"];
                displayTextureCoordinateAttribute = [_program attributeIndex:@"inputTextureCoordinate"];
                displayInputTextureUniform = [_program uniformIndex:@"inputImageTexture"];
                
                [_program use];
                glEnableVertexAttribArray(displayPositionAttribute);
                glEnableVertexAttribArray(displayTextureCoordinateAttribute);
            }
        }
    });
    return ret;
}

- (void)renderWithTextureId:(int) inputTex timimgInfo:(CMSampleTimingInfo) timimgInfo;
{
    glFinish();
    dispatch_async([_encoderContext contextQueue], ^{
        [_encoderContext useAsCurrentContext];
        [self setFilterFBO];
        [_program use];
        glClearColor(1.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
        glActiveTexture(GL_TEXTURE4);
        glBindTexture(GL_TEXTURE_2D, inputTex);
        glUniform1i(displayInputTextureUniform, 4);
        
        static const GLfloat imageVertices[] = {
            -1.0f, -1.0f,
            1.0f, -1.0f,
            -1.0f,  1.0f,
            1.0f,  1.0f,
        };
        
        static const GLfloat noRotationTextureCoordinates[] = {
            0.0f, 1.0f,
            1.0f, 1.0f,
            0.0f, 0.0f,
            1.0f, 0.0f,
        };
        
        glVertexAttribPointer(displayPositionAttribute, 2, GL_FLOAT, 0, 0, imageVertices);
        glEnableVertexAttribArray(displayPositionAttribute);
        glVertexAttribPointer(displayTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, noRotationTextureCoordinates);
        glEnableVertexAttribArray(displayTextureCoordinateAttribute);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        glFinish();
        
        //取出对应的这一帧图像 然后进行组成CMSampleBufferRef 最后进行编码
        CVPixelBufferRef pixel_buffer = NULL;
        if([ELImageContext supportsFastTextureUpload]){
            pixel_buffer = renderTarget;
            CVReturn status = CVPixelBufferLockBaseAddress(pixel_buffer, 0);
            if(status != kCVReturnSuccess){
                NSLog(@"CVPixelBufferLockBaseAddress pixel_buffer Failed...");
            }
        } else{
            int bitmapBytesPerRow   = _width * 4;
            OSType pixFmt = kCVPixelFormatType_32BGRA;
            CVReturn status = CVPixelBufferCreateWithBytes(kCFAllocatorDefault, _width, _height, pixFmt, [self renderTargetBuf], bitmapBytesPerRow, NULL, NULL, NULL, &pixel_buffer);
            if ((pixel_buffer == NULL) || (status != kCVReturnSuccess)){
                CVPixelBufferRelease(pixel_buffer);
                return;
            }else {
                CVPixelBufferLockBaseAddress(pixel_buffer, 0);
                GLubyte *pixelBufferData = (GLubyte *)CVPixelBufferGetBaseAddress(pixel_buffer);
                glReadPixels(0, 0, _width, _height, GL_RGBA, GL_UNSIGNED_BYTE, pixelBufferData);
            }
        }
        
        CMSampleBufferRef encodeSampleBuffer = NULL;
        CMVideoFormatDescriptionRef videoInfo = NULL;
        CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixel_buffer, &videoInfo);
        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixel_buffer, true, NULL, NULL, videoInfo, &timimgInfo, &encodeSampleBuffer);
        [[self h264Encoder] encode:encodeSampleBuffer];
        CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);
        if(![ELImageContext supportsFastTextureUpload]){
            CVPixelBufferRelease(pixel_buffer);
        }
        CFRelease(videoInfo);
        CFRelease(encodeSampleBuffer);
    });
}

- (uint8_t*)renderTargetBuf;
{
    if(nil == _renderTargetBuf){
        int bitmapBytesPerRow   = _width * 4;
        int bitmapByteCount     = bitmapBytesPerRow * _height;
        _renderTargetBuf = new uint8_t[bitmapByteCount];
        memset(_renderTargetBuf, 0, sizeof(uint8_t) * bitmapByteCount);
    }
    return _renderTargetBuf;
}

- (H264HwEncoderImpl *)h264Encoder
{
    if(!_h264Encoder)
    {
        _h264Encoder = [[H264HwEncoderImpl alloc] init];
        [_h264Encoder initWithConfiguration];
        _h264Encoder.delegate = self.H264HwEncoderHandler;
        _h264Encoder.encoderStatusDelegate = _encoderStatusDelegate;
        [_h264Encoder initEncode:_width height:_height fps:(int)_fps maxBitRate:_maxBitRate avgBitRate:_avgBitRate];
    }
    return _h264Encoder;
}

- (H264HwEncoderHandler *)H264HwEncoderHandler
{
    if(!_H264HwEncoderHandler)
    {
        _H264HwEncoderHandler = [[H264HwEncoderHandler alloc] init];
    }
    return _H264HwEncoderHandler;
}

- (void)setFilterFBO;
{
    if (!_encodeFramebuffer)
    {
        [self createDataFBO];
    }
    glBindFramebuffer(GL_FRAMEBUFFER, _encodeFramebuffer);
    glViewport(0, 0, _width, _height);
}

- (void) createRenderTargetWithSpecifiedPool;
{
    NSMutableDictionary*     attributes;
    attributes = [NSMutableDictionary dictionary];
    [attributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
    [attributes setObject:[NSNumber numberWithInt:_width] forKey: (NSString*)kCVPixelBufferWidthKey];
    [attributes setObject:[NSNumber numberWithInt:_height] forKey: (NSString*)kCVPixelBufferHeightKey];
    CVPixelBufferPoolRef bufferPool = NULL;
    CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef) attributes, &bufferPool);
    CVPixelBufferPoolCreatePixelBuffer (NULL, bufferPool, &renderTarget);
    //TODO:需要释放
//    CVPixelBufferPoolRelease(bufferPool);
}

- (void) createRenderTargetWithSpecifiedMemPtr;
{
    int bitmapBytesPerRow   = _width * 4;
    OSType pixFmt = kCVPixelFormatType_32BGRA;
    CVPixelBufferCreateWithBytes(kCFAllocatorDefault, _width, _height, pixFmt, [self renderTargetBuf], bitmapBytesPerRow, NULL, NULL, NULL, &renderTarget);
    
    /* AVAssetWriter will use BT.601 conversion matrix for RGB to YCbCr conversion
     * regardless of the kCVImageBufferYCbCrMatrixKey value.
     * Tagging the resulting video file as BT.601, is the best option right now.
     * Creating a proper BT.709 video is not possible at the moment.
     */
    CVBufferSetAttachment(renderTarget, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, kCVAttachmentMode_ShouldPropagate);
    CVBufferSetAttachment(renderTarget, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_601_4, kCVAttachmentMode_ShouldPropagate);
    CVBufferSetAttachment(renderTarget, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, kCVAttachmentMode_ShouldPropagate);
}

- (void) createRenderTargetWithSpecifiedAttrs;
{
    CFDictionaryRef empty; // empty value for attr value.
    CFMutableDictionaryRef attrs;
    empty = CFDictionaryCreate(kCFAllocatorDefault, // our empty IOSurface properties dictionary
                               NULL,
                               NULL,
                               0,
                               &kCFTypeDictionaryKeyCallBacks,
                               &kCFTypeDictionaryValueCallBacks);
    attrs = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                      1,
                                      &kCFTypeDictionaryKeyCallBacks,
                                      &kCFTypeDictionaryValueCallBacks);
    
    CFDictionarySetValue(attrs,
                         kCVPixelBufferIOSurfacePropertiesKey,
                         empty);
    CVPixelBufferCreate(kCFAllocatorDefault, _width, _height,
                        kCVPixelFormatType_32BGRA,
                        attrs,
                        &renderTarget);
    CFRelease(attrs);
    CFRelease(empty);
}

- (void)createDataFBO;
{
    glActiveTexture(GL_TEXTURE1);
    glGenFramebuffers(1, &_encodeFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _encodeFramebuffer);
    if([ELImageContext supportsFastTextureUpload]){
        /*************** Directly Create CVPixelBuffer With Our Specified Attrs *****************/
        [self createRenderTargetWithSpecifiedAttrs];
        /*************** Directly Create CVPixelBuffer With Our Allocated Memory *****************/
//        [self createRenderTargetWithSpecifiedMemPtr];
        /*************** Create CVPixelBuffer With Pixel Buffer Pool *****************/
//        [self createRenderTargetWithSpecifiedPool];
        
        CVOpenGLESTextureCacheCreateTextureFromImage (kCFAllocatorDefault,
                                                      [_encoderContext coreVideoTextureCache],
                                                      renderTarget,
                                                      NULL, // texture attributes
                                                      GL_TEXTURE_2D,
                                                      GL_RGBA, // opengl format
                                                      _width,
                                                      _height,
                                                      GL_BGRA, // native iOS format
                                                      GL_UNSIGNED_BYTE,
                                                      0,
                                                      &renderTexture);
        glBindTexture(CVOpenGLESTextureGetTarget(renderTexture), CVOpenGLESTextureGetName(renderTexture));
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(renderTexture), 0);
        NSLog(@"Create render Texture Success...");
    } else{
        glGenRenderbuffers(1, &_encodeRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _encodeRenderbuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8_OES, _width, _height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _encodeRenderbuffer);
    }
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if(status != GL_FRAMEBUFFER_COMPLETE){
        NSLog(@"Incomplete filter FBO: %d", status);
    }
}

- (void) stopEncode;
{
    [self destroyDataFBO];
    [[self h264Encoder] endCompresseion];
    if(_renderTargetBuf){
        delete[] _renderTargetBuf;
        _renderTargetBuf = nil;
    }
}

- (void)destroyDataFBO;
{
    dispatch_sync([_encoderContext contextQueue], ^{
        [_encoderContext useAsCurrentContext];
        if (_encodeFramebuffer)
        {
            glDeleteFramebuffers(1, &_encodeFramebuffer);
            _encodeFramebuffer = 0;
        }
        if (_encodeRenderbuffer)
        {
            glDeleteRenderbuffers(1, &_encodeRenderbuffer);
            _encodeRenderbuffer = 0;
        }
        if([ELImageContext supportsFastTextureUpload]){
            if (renderTexture)
            {
                CFRelease(renderTexture);
            }
            if (renderTarget)
            {
//                CVPixelBufferRelease(renderTarget);
                CVBufferRelease(renderTarget);
            }
            NSLog(@"Release Render Texture and Target Success...");
        }
    });
}

@end
