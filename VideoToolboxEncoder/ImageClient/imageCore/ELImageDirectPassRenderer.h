//
//  DirectPassRenderer.h
//  liveDemo
//
//  Created by apple on 16/3/1.
//  Copyright © 2016年 changba. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ELImageTextureFrame.h"

@interface ELImageDirectPassRenderer : NSObject

- (BOOL) prepareRender;

- (void) renderWithTextureId:(int) inputTex width:(int) width height:(int) height aspectRatio:(float)aspectRatio;

@end
