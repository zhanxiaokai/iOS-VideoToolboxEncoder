//
//  CameraPreviewRenderer.m
//  liveDemo
//
//  Created by apple on 16/2/29.
//  Copyright © 2016年 changba. All rights reserved.
//

#import "ELImageCameraRenderer.h"
#import "ELImageContext.h"
#import "ELImageProgram.h"
#import "ELImageOutput.h"

NSString *const vertexShaderString = SHADER_STRING
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

NSString *const fragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 uniform mediump mat3 colorConversionMatrix;
 
 void main()
 {
     mediump vec3 yuv;
     lowp vec3 rgb;
     
     yuv.x = texture2D(luminanceTexture, textureCoordinate).r;
     yuv.yz = texture2D(chrominanceTexture, textureCoordinate).ra - vec2(0.5, 0.5);
     rgb = colorConversionMatrix * yuv;
     
     gl_FragColor = vec4(rgb, 1);
 }
 );

NSString *const YUVVideoRangeConversionForLAFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 uniform mediump mat3 colorConversionMatrix;
 
 void main()
 {
     mediump vec3 yuv;
     lowp vec3 rgb;
     
     yuv.x = texture2D(luminanceTexture, textureCoordinate).r - (16.0/255.0);
     yuv.yz = texture2D(chrominanceTexture, textureCoordinate).ra - vec2(0.5, 0.5);
     rgb = colorConversionMatrix * yuv;
     
     gl_FragColor = vec4(rgb, 1);
 }
 );

@implementation ELImageCameraRenderer{
    ELImageProgram*     program;
    
    GLuint          luminanceTexture;
    GLuint          chrominanceTexture;
    
    GLint positionAttribute, textureCoordinateAttribute;
    GLint luminanceTextureUniform, chrominanceTextureUniform;
    GLint matrixUniform;
}

- (BOOL) prepareRender:(BOOL) isFullYUVRange;
{
    BOOL ret = FALSE;
    if(isFullYUVRange){
        program = [[ELImageProgram alloc] initWithVertexShaderString:vertexShaderString fragmentShaderString:fragmentShaderString];
    } else{
        program = [[ELImageProgram alloc] initWithVertexShaderString:vertexShaderString fragmentShaderString:YUVVideoRangeConversionForLAFragmentShaderString];
    }
    if(program){
        [program addAttribute:@"position"];
        [program addAttribute:@"inputTextureCoordinate"];
        if([program link]){
            positionAttribute = [program attributeIndex:@"position"];
            textureCoordinateAttribute = [program attributeIndex:@"inputTextureCoordinate"];
            luminanceTextureUniform = [program uniformIndex:@"luminanceTexture"];
            chrominanceTextureUniform = [program uniformIndex:@"chrominanceTexture"];
            matrixUniform = [program uniformIndex:@"colorConversionMatrix"];
            
            [program use];
            glEnableVertexAttribArray(positionAttribute);
            glEnableVertexAttribArray(textureCoordinateAttribute);
            
            ret = TRUE;
        }
    }
    return ret;
}

- (void) renderWithSampleBuffer:(CMSampleBufferRef) sampleBuffer aspectRatio:(float)aspectRatio preferredConversion:(const GLfloat *)preferredConversion imageRotation:(ELImageRotationMode) inputTexRotation;
{
//    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
    int bufferWidth = (int) CVPixelBufferGetWidth(cameraFrame);
    int bufferHeight = (int) CVPixelBufferGetHeight(cameraFrame);
//    CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
    [program use];
    CVOpenGLESTextureRef luminanceTextureRef = NULL;
    CVOpenGLESTextureRef chrominanceTextureRef = NULL;
    
    CVPixelBufferLockBaseAddress(cameraFrame, 0);
    CVReturn err;

    // Y-plane
    glActiveTexture(GL_TEXTURE4);
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[ELImageContext sharedImageProcessingContext] coreVideoTextureCache], cameraFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
    if (err)
    {
        NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
        
    luminanceTexture = CVOpenGLESTextureGetName(luminanceTextureRef);
    glBindTexture(GL_TEXTURE_2D, luminanceTexture);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
    // UV-plane
    glActiveTexture(GL_TEXTURE5);
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[ELImageContext sharedImageProcessingContext] coreVideoTextureCache], cameraFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
    if (err)
    {
        NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
    chrominanceTexture = CVOpenGLESTextureGetName(chrominanceTextureRef);
    glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    [self convertYUVToRGBOutputWithWidth:bufferWidth height:bufferHeight aspectRatio:aspectRatio preferredConversion:preferredConversion inputTexRotation:inputTexRotation];

    CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
    CFRelease(luminanceTextureRef);
    CFRelease(chrominanceTextureRef);
}

- (void)convertYUVToRGBOutputWithWidth:(int) bufferWidth height:(int) bufferHeight aspectRatio:(float)aspectRatio preferredConversion:(const GLfloat *)preferredConversion inputTexRotation:(ELImageRotationMode) inputTexRotation;
{
    int targetWidth = bufferHeight / aspectRatio;
    int targetHeight = bufferHeight;
    float fromX = (float)((bufferWidth - targetWidth) / 2) / (float) bufferWidth;
    float toX = 1.0f - fromX;
    glViewport(0, 0, targetWidth, targetHeight);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    GLfloat rotate180TextureCoordinates[] = {
        fromX, 1.0f,
        toX, 1.0f,
        fromX, 0.0f,
        toX, 0.0f,
    };
    if(inputTexRotation == kELImageFlipHorizontal){
        rotate180TextureCoordinates[0] = toX;
        rotate180TextureCoordinates[2] = fromX;
        rotate180TextureCoordinates[4] = toX;
        rotate180TextureCoordinates[6] = fromX;
    }
    
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, luminanceTexture);
    glUniform1i(luminanceTextureUniform, 4);
    
    glActiveTexture(GL_TEXTURE5);
    glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
    glUniform1i(chrominanceTextureUniform, 5);
    
    glUniformMatrix3fv(matrixUniform, 1, GL_FALSE, preferredConversion);
    
    glVertexAttribPointer(positionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
    glEnableVertexAttribArray(positionAttribute);
    glVertexAttribPointer(textureCoordinateAttribute, 2, GL_FLOAT, 0, 0, rotate180TextureCoordinates);
    glEnableVertexAttribArray(textureCoordinateAttribute);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

@end
