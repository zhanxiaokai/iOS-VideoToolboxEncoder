//
//  GPUProgram.h
//  liveDemo
//
//  Created by apple on 16/3/1.
//  Copyright © 2016年 changba. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

//from GPUImage
#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

@interface ELImageProgram : NSObject

- (void)use;

- (BOOL)link;

- (GLuint)uniformIndex:(NSString *)uniformName;

- (GLuint)attributeIndex:(NSString *)attributeName;

- (void)addAttribute:(NSString *)attributeName;

- (id) initWithVertexShaderString:(NSString *)vShaderString fragmentShaderString:(NSString *)fShaderString;

@end
