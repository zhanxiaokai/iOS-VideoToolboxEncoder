#import "ELPushStreamViewController.h"
#import "ELImageVideoScheduler.h"
#import "ELPushStreamConfigeration.h"

#define buttonWidth 50.0f

@interface ELPushStreamViewController () <ELVideoEncoderStatusDelegate>
{
    ELImageVideoScheduler*          _videoScheduler;
    
    UIButton*                       _encoderBtn;
    BOOL                            _started;
}
@end

@implementation ELPushStreamViewController

#pragma -mark life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    CGRect bounds = self.view.bounds;
    _videoScheduler = [[ELImageVideoScheduler alloc] initWithFrame:bounds videoFrameRate:kFrameRate];
    [self.view insertSubview:[_videoScheduler previewView] atIndex:0];
    [self addEncoderBtn];
}

- (void) addEncoderBtn
{
    _encoderBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    CGFloat screenWidth = self.view.bounds.size.width;
    CGFloat screenHeight = self.view.bounds.size.height;
    CGRect huge = CGRectMake((screenWidth - buttonWidth) / 2, screenHeight - buttonWidth - 30, buttonWidth, buttonWidth);
    [_encoderBtn setFrame:huge];
    [_encoderBtn setTitle:@"Start" forState:UIControlStateNormal];
    [_encoderBtn setTitle:@"Stop" forState:UIControlStateSelected];
    [_encoderBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_encoderBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
    _encoderBtn.layer.cornerRadius = buttonWidth/2.0f;
    _encoderBtn.layer.borderWidth = 1.0f;
    _encoderBtn.layer.borderColor = [UIColor blackColor].CGColor;
    [_encoderBtn addTarget:self action:@selector(OnStartStop:) forControlEvents:UIControlEventTouchUpInside];
    //按钮初始状态
    [_encoderBtn setSelected:NO];
    [self.view addSubview:_encoderBtn];
    [self.view bringSubviewToFront:_encoderBtn];
}

// Called when start/stop button is pressed
- (void)OnStartStop:(id)sender {
    if (_started)
    {
        [_videoScheduler stopEncode];
        _started = NO;
        [_encoderBtn setSelected:NO];
    }
    else
    {
        [_videoScheduler startEncodeWithFPS:kFrameRate maxBitRate:kMaxVideoBitRate avgBitRate:kAVGVideoBitRate encoderWidth:kDesiredWidth encoderHeight:kDesiredHeight encoderStatusDelegate:self];
        _started = YES;
        [_encoderBtn setSelected:YES];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [_videoScheduler startPreview];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [_videoScheduler stopPreview];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma -mark Encoder Delegate
- (void) onEncoderInitialFailed{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_videoScheduler stopEncode];
        //您的直播无法正常播放(编码器初始化失败)，请立即联系客服人员
        UIAlertView *alterView = [[UIAlertView alloc] initWithTitle:@"提示信息"
                                                            message:@"您的直播无法播放，请立即联系客服人员"
                                                           delegate:self
                                                  cancelButtonTitle:@"取消"
                                                  otherButtonTitles: nil];
        [alterView show];
    });
}

- (void) onEncoderEncodedFailed{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_videoScheduler stopEncode];
        //您的直播无法正常播放(编码器编码视频失败)，请立即联系客服人员
        UIAlertView *alterView = [[UIAlertView alloc] initWithTitle:@"提示信息"
                                                            message:@"您的直播无法正常播放了，请立即联系客服人员"
                                                           delegate:self cancelButtonTitle:@"取消" otherButtonTitles: nil];
        [alterView show];
    });
}

@end
