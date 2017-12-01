//
//  CameraPreviewRenderer.h
//  liveDemo
//
//  Created by apple on 16/2/29.
//  Copyright © 2016年 changba. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ELImageContext.h"

@interface ELImageCameraRenderer : NSObject

- (BOOL) prepareRender:(BOOL) isFullYUVRange;

- (void) renderWithSampleBuffer:(CMSampleBufferRef) sampleBuffer aspectRatio:(float)aspectRatio preferredConversion:(const GLfloat *) preferredConversion imageRotation:(ELImageRotationMode) inputTexRotation;

@end
