#import "H264HwEncoderImpl.h"
#import <UIKit/UIKit.h>
#include <sys/sysctl.h>

@interface H264HwEncoderImpl()
{
    
}

@property(atomic,assign) BOOL initialized;

@end

@implementation H264HwEncoderImpl
{
    VTCompressionSessionRef                     EncodingSession;
    dispatch_queue_t                            aQueue;
    CMFormatDescriptionRef                      format;
    CMSampleTimingInfo *                        timingInfo;
    int64_t                                     encodingTimeMills;
    int                                         m_fps;
    int                                         m_maxBitRate;
    int                                         m_avgBitRate;
    NSData *                                    sps;
    NSData *                                    pps;
    
    CFBooleanRef                                has_b_frames_cfbool;
    int64_t last_dts;
}

@synthesize error;

- (void)initWithConfiguration
{
    EncodingSession = nil;
    aQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    encodingTimeMills = -1;
    sps = NULL;
    pps = NULL;
    continuousEncodeFailureTimes = 0;
}

- (void)initEncode:(int)width height:(int)height fps:(int)fps maxBitRate:(int)maxBitRate avgBitRate:(int)avgBitRate;
{
    dispatch_sync(aQueue, ^{
        // Create the compression session
        OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self),  &EncodingSession);
        if (status != 0)
        {
            NSLog(@"H264: Unable to create a H264 session status is %d", status);
            [_encoderStatusDelegate onEncoderInitialFailed];
            error = @"H264: Unable to create a H264 session";
            return ;
        }
        
        // Set the properties
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel);
        VTSessionSetProperty(EncodingSession , kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
        [self settingMaxBitRate:maxBitRate avgBitRate: avgBitRate fps:fps];
        
        // Tell the encoder to start encoding
        VTCompressionSessionPrepareToEncodeFrames(EncodingSession);
        
        status = VTSessionCopyProperty(EncodingSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFAllocatorDefault, &has_b_frames_cfbool);
        
        self.initialized = YES;
        encodingSessionValid = true;
    });
}

- (void) settingMaxBitRate:(int)maxBitRate avgBitRate:(int)avgBitRate fps:(int)fps;
{
    NSLog(@"设置avgBitRate %dKb", avgBitRate / 1024);
    m_fps = fps;
    VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)(@(fps)));
    VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)(@(fps)));
    if(![self isInSettingDataRateLimitsBlackList]){
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)@[@(maxBitRate / 8), @1.0]);
    }
    VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(avgBitRate));
}

- (BOOL) isInSettingDataRateLimitsBlackList
{
    BOOL ret = false;
    NSString* systemVersion = [[UIDevice currentDevice] systemVersion];
    NSArray* prefixBlackList = [NSArray arrayWithObjects:@"8.2", @"8.1", nil];
    for (NSString* prefix in prefixBlackList) {
        if([systemVersion hasPrefix:prefix]){
            ret = true;
            break;
        }
    }
    if(ret){
        //如果满足黑名单 就判断低于iPhone6的设备（iPhone5C iPhone5S ）返回False（否则花屏）
        if(![self isIphoneOnlyAnd6Upper]){
            ret = false;
        }
    }
    return ret;
}

- (void)encode:(CMSampleBufferRef )sampleBuffer
{
    if(continuousEncodeFailureTimes > CONTINUOUS_ENCODE_FAILURE_TIMES_TRESHOLD){
        [_encoderStatusDelegate onEncoderEncodedFailed];
    }
    dispatch_sync(aQueue, ^{
        if(!self.initialized)
            return;
        int64_t currentTimeMills = CFAbsoluteTimeGetCurrent() * 1000;
        if(-1 == encodingTimeMills){
            encodingTimeMills = currentTimeMills;
        }
        int64_t encodingDuration = currentTimeMills - encodingTimeMills;
        // Get the CV Image buffer
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        
        // Create properties
        CMTime pts = CMTimeMake(encodingDuration, 1000.); // timestamp is in ms.
        CMTime dur = CMTimeMake(1, m_fps);
        VTEncodeInfoFlags flags;
        
        // Pass it to the encoder
        OSStatus statusCode = VTCompressionSessionEncodeFrame(EncodingSession,
                                                              imageBuffer,
                                                              pts,
                                                              dur,
                                                              NULL, NULL, &flags);
        // Check for error
        if (statusCode != noErr) {
            error = @"H264: VTCompressionSessionEncodeFrame failed ";
            return;
        }
    });
}

static int continuousEncodeFailureTimes;
static bool encodingSessionValid = false;
void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags,
                     CMSampleBufferRef sampleBuffer )
{
    //    NSLog(@"didCompressH264 called with status %d infoFlags %d", (int)status, (int)infoFlags);
    if (status != noErr) {
        continuousEncodeFailureTimes++;
        return;
    }
    continuousEncodeFailureTimes = 0;
    if (!CMSampleBufferDataIsReady(sampleBuffer))
    {
        //        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    if(!encodingSessionValid){
        return;
    }
    H264HwEncoderImpl* encoder = (__bridge H264HwEncoderImpl*)outputCallbackRefCon;
    // Check if we have got a key frame first
    bool keyframe = !CFDictionaryContainsKey( (CFDictionaryRef)(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), (const void *)kCMSampleAttachmentKey_NotSync);
    
    if(keyframe)
    {
        if(encoder)
        {
            CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
            // Get the extensions
            // From the extensions get the dictionary with key "SampleDescriptionExtensionAtoms"
            // From the dict, get the value for the key "avcC"
            size_t sparameterSetSize, sparameterSetCount;
            const uint8_t *sparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
            if (statusCode == noErr)
            {
                // Found sps and now check for pps
                size_t pparameterSetSize, pparameterSetCount;
                const uint8_t *pparameterSet;
                OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
                if (statusCode == noErr)
                {
                    // Found pps
                    encoder->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                    encoder->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                    if (encoder->_delegate)
                    {
                        double timeMills = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))*1000;
                        [encoder->_delegate gotSpsPps:encoder->sps pps:encoder->pps timestramp:timeMills fromEncoder:encoder];
                    }
                }
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            // Convert the length value from Big-endian to Little-endian
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            CMTime presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            double presentationTimeMills = CMTimeGetSeconds(presentationTimeStamp)*1000;
            int64_t pts = presentationTimeMills / 1000.0f * 1000;
            int64_t dts = pts;
            [encoder->_delegate gotEncodedData:data isKeyFrame:keyframe timestramp:presentationTimeMills pts:pts dts:dts fromEncoder:encoder];
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}

- (void)endCompresseion
{
    NSLog(@"begin endCompresseion ");
    self.initialized = NO;
    encodingSessionValid = false;
    // Mark the completion
    VTCompressionSessionCompleteFrames(EncodingSession, kCMTimeInvalid);
    // End the session
    VTCompressionSessionInvalidate(EncodingSession);
    CFRelease(EncodingSession);
    NSLog(@"endCompresseion success");
    EncodingSession = NULL;
    error = NULL;
}

- (BOOL) isIphoneOnlyAnd6Upper
{
    NSString *platform = [self platform];
    if (([platform rangeOfString:@"iPhone"].location != NSNotFound) && ([platform compare:@"iPhone7,0"] == NSOrderedDescending))
    {
        return YES;
    }
    return NO;
}

- (NSString *) getSysInfoByName:(char *)typeSpecifier
{
    size_t size;
    sysctlbyname(typeSpecifier, NULL, &size, NULL, 0);
    
    char* answer = (char*)malloc(size);
    sysctlbyname(typeSpecifier, answer, &size, NULL, 0);
    
    NSString *results = @(answer);
    
    free(answer);
    return results;
}

- (NSString *) platform
{
    return [self getSysInfoByName:"hw.machine"];
}

@end
