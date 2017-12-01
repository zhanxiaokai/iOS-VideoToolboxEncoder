//
//  DirectPassRenderer.m
//  liveDemo
//
//  Created by apple on 16/3/1.
//  Copyright © 2016年 changba. All rights reserved.
//

#import "ELImageDirectPassRenderer.h"
#import "ELImageProgram.h"

NSString *const directPassVertexShaderString = SHADER_STRING
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

NSString *const directPassFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
 }
 );

@implementation ELImageDirectPassRenderer
{
    ELImageProgram*     _program;
    GLint displayPositionAttribute, displayTextureCoordinateAttribute;
    GLint displayInputTextureUniform;
    
}

- (BOOL) prepareRender;
{
    BOOL ret = FALSE;
    _program = [[ELImageProgram alloc] initWithVertexShaderString:directPassVertexShaderString fragmentShaderString:directPassFragmentShaderString];
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
            ret = TRUE;
        }
    }
    return ret;
}

- (void) renderWithTextureId:(int) inputTex width:(int) width height:(int) height aspectRatio:(float)aspectRatio;
{
    float fromY = 0.0f;
    float toY = 1.0f;
    float displayAspectRatio = (float)height / (float)width;
    if(displayAspectRatio != aspectRatio){
        if(displayAspectRatio < aspectRatio){
            float distance = displayAspectRatio / aspectRatio;
            fromY = (1.0f - distance) / 2.0f;
            toY = fromY + distance;
        }
    }

    [_program use];
    glViewport(0, 0, width, height);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
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
    
    GLfloat noRotationTextureCoordinates[] = {
        0.0f, fromY,
        1.0f, fromY,
        0.0f, toY,
        1.0f, toY,
    };
    
    glVertexAttribPointer(displayPositionAttribute, 2, GL_FLOAT, 0, 0, imageVertices);
    glEnableVertexAttribArray(displayPositionAttribute);
    glVertexAttribPointer(displayTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, noRotationTextureCoordinates);
    glEnableVertexAttribArray(displayTextureCoordinateAttribute);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

@end
