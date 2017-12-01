#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include <VideoToolbox/VideoToolbox.h>

#define CONTINUOUS_ENCODE_FAILURE_TIMES_TRESHOLD                              100

@protocol ELVideoEncoderStatusDelegate <NSObject>

- (void) onEncoderInitialFailed;

- (void) onEncoderEncodedFailed;

@end

@class H264HwEncoderImpl;

@protocol H264HwEncoderImplDelegate <NSObject>

- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps timestramp:(Float64)miliseconds fromEncoder:(H264HwEncoderImpl*)encoder;
- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame timestramp:(Float64)miliseconds pts:(int64_t) pts dts:(int64_t) dts fromEncoder:(H264HwEncoderImpl*)encoder;

@end

@interface H264HwEncoderImpl : NSObject 

- (void)initWithConfiguration;
- (void)initEncode:(int)width height:(int)height fps:(int)fps maxBitRate:(int)maxBitRate avgBitRate:(int)avgBitRate;
- (void) settingMaxBitRate:(int)maxBitRate avgBitRate:(int)avgBitRate fps:(int)fps;
- (void)encode:(CMSampleBufferRef )sampleBuffer;
- (void)endCompresseion;

@property (weak, nonatomic) NSString *error;
@property (weak, nonatomic) id<H264HwEncoderImplDelegate> delegate;
@property (nonatomic, weak) id<ELVideoEncoderStatusDelegate> encoderStatusDelegate;

@end
