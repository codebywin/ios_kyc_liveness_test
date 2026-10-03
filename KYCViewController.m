#import "KYCViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface KYCViewController () <AVCaptureVideoDataOutputSampleBufferDelegate> {
    AVCaptureSession *_captureSession;
    AVCaptureVideoPreviewLayer *_previewLayer;
    
    UIView *_colorBorderView;
    CAShapeLayer *_ovalMaskLayer;
    UILabel *_statusLabel;
    UILabel *_instructionLabel;
    UIButton *_toggleFlashButton;
    
    NSTimer *_flashTimer;
    NSInteger _colorIndex;
    BOOL _isFlashing;
    NSArray<UIColor *> *_flashColors;
    NSArray<NSString *> *_colorNames;
}
@end

@implementation KYCViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    _colorIndex = 0;
    _isFlashing = NO;
    
    // 6 dải màu chớp chuẩn của FaceTec, Sumsub & eKYC ngân hàng
    _flashColors = @[
        [UIColor colorWithRed:1.0 green:0.05 blue:0.05 alpha:1.0], // Đỏ
        [UIColor colorWithRed:0.05 green:0.95 blue:0.15 alpha:1.0], // Xanh lục
        [UIColor colorWithRed:0.10 green:0.40 blue:1.0 alpha:1.0],  // Xanh lam
        [UIColor colorWithRed:1.0 green:0.90 blue:0.05 alpha:1.0],  // Vàng
        [UIColor colorWithRed:0.05 green:0.90 blue:0.95 alpha:1.0], // Xanh ngọc (Cyan)
        [UIColor colorWithRed:0.95 green:0.15 blue:0.95 alpha:1.0]  // Tím hồng (Magenta)
    ];
    
    _colorNames = @[@"ĐỎ (Red)", @"XANH LỤC (Green)", @"XANH LAM (Blue)", @"VÀNG (Yellow)", @"CYAN (Xanh ngọc)", @"TÍM (Magenta)"];
    
    [self setupCamera];
    [self setupUI];
}

- (void)setupCamera {
    _captureSession = [[AVCaptureSession alloc] init];
    _captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    
    AVCaptureDevice *frontCamera = nil;
    if (@available(iOS 10.0, *)) {
        AVCaptureDeviceDiscoverySession *discovery = [AVCaptureDeviceDiscoverySession
            discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
            mediaType:AVMediaTypeVideo
            position:AVCaptureDevicePositionFront];
        frontCamera = discovery.devices.firstObject;
    }
    
    if (!frontCamera) {
        frontCamera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    if (frontCamera) {
        NSError *err = nil;
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:&err];
        if ([_captureSession canAddInput:input]) {
            [_captureSession addInput:input];
        }
        
        AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
        [output setSampleBufferDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];
        if ([_captureSession canAddOutput:output]) {
            [_captureSession addOutput:output];
        }
    }
    
    _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_captureSession];
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _previewLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:_previewLayer];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self->_captureSession startRunning];
    });
}

- (void)setupUI {
    CGRect bounds = self.view.bounds;
    
    // 1. Lớp viền màn hình đổi màu chớp KYC
    _colorBorderView = [[UIView alloc] initWithFrame:bounds];
    _colorBorderView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.85];
    _colorBorderView.userInteractionEnabled = NO;
    [self.view addSubview:_colorBorderView];
    
    // 2. Cắt lỗ Oval ở giữa màn hình (mô phỏng khung đưa mặt vào)
    CGFloat ovalW = bounds.size.width * 0.72;
    CGFloat ovalH = ovalW * 1.35;
    CGFloat ovalX = (bounds.size.width - ovalW) / 2.0;
    CGFloat ovalY = (bounds.size.height - ovalH) / 2.0 - 20;
    CGRect ovalRect = CGRectMake(ovalX, ovalY, ovalW, ovalH);
    
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:bounds];
    UIBezierPath *ovalPath = [UIBezierPath bezierPathWithOvalInRect:ovalRect];
    [path appendPath:ovalPath];
    [path setUsesEvenOddFillRule:YES];
    
    _ovalMaskLayer = [CAShapeLayer layer];
    _ovalMaskLayer.path = path.CGPath;
    _ovalMaskLayer.fillRule = kCAFillRuleEvenOdd;
    _colorBorderView.layer.mask = _ovalMaskLayer;
    
    // Viền trắng bao quanh lỗ Oval
    CAShapeLayer *ovalBorder = [CAShapeLayer layer];
    ovalBorder.path = ovalPath.CGPath;
    ovalBorder.fillColor = [UIColor clearColor].CGColor;
    ovalBorder.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.9].CGColor;
    ovalBorder.lineWidth = 3.0;
    [self.view.layer addSublayer:ovalBorder];
    
    // 3. Nhãn chỉ dẫn
    _instructionLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, ovalY - 60, bounds.size.width - 40, 30)];
    _instructionLabel.text = @"Giữ khuôn mặt trong khung hình";
    _instructionLabel.textColor = [UIColor whiteColor];
    _instructionLabel.font = [UIFont boldSystemFontOfSize:17];
    _instructionLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_instructionLabel];
    
    // 4. Nhãn trạng thái màu hiện tại
    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, CGRectGetMaxY(ovalRect) + 20, bounds.size.width - 40, 45)];
    _statusLabel.text = @"Trạng thái: Chưa chớp màu";
    _statusLabel.textColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.3 alpha:1.0];
    _statusLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    _statusLabel.numberOfLines = 2;
    [self.view addSubview:_statusLabel];
    
    // 5. Nút Bắt đầu / Dừng chớp màu
    _toggleFlashButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _toggleFlashButton.frame = CGRectMake((bounds.size.width - 220) / 2.0, bounds.size.height - 95, 220, 50);
    _toggleFlashButton.backgroundColor = [UIColor colorWithRed:0.15 green:0.65 blue:1.0 alpha:1.0];
    _toggleFlashButton.layer.cornerRadius = 25;
    _toggleFlashButton.layer.masksToBounds = YES;
    [_toggleFlashButton setTitle:@"⚡ Bắt Đầu Chớp Màu" forState:UIControlStateNormal];
    _toggleFlashButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [_toggleFlashButton addTarget:self action:@selector(toggleFlashing) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_toggleFlashButton];
}

- (void)toggleFlashing {
    _isFlashing = !_isFlashing;
    if (_isFlashing) {
        [_toggleFlashButton setTitle:@"⏹ Dừng Chớp Màu" forState:UIControlStateNormal];
        _toggleFlashButton.backgroundColor = [UIColor colorWithRed:0.95 green:0.25 blue:0.25 alpha:1.0];
        _colorIndex = 0;
        
        // Nhịp chớp 450ms chuẩn eKYC
        _flashTimer = [NSTimer scheduledTimerWithTimeInterval:0.45 target:self selector:@selector(tickFlash) userInfo:nil repeats:YES];
        [self tickFlash];
    } else {
        [_flashTimer invalidate];
        _flashTimer = nil;
        [_toggleFlashButton setTitle:@"⚡ Bắt Đầu Chớp Màu" forState:UIControlStateNormal];
        _toggleFlashButton.backgroundColor = [UIColor colorWithRed:0.15 green:0.65 blue:1.0 alpha:1.0];
        _colorBorderView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.85];
        _statusLabel.text = @"Đã dừng chớp màu (Trạng thái tĩnh)";
    }
}

- (void)tickFlash {
    UIColor *col = _flashColors[_colorIndex];
    NSString *name = _colorNames[_colorIndex];
    
    [UIView animateWithDuration:0.1 animations:^{
        self->_colorBorderView.backgroundColor = col;
    }];
    
    _statusLabel.text = [NSString stringWithFormat:@"Đang chớp: %@\n(Quan sát khuôn mặt xem có đổi màu theo không)", name];
    
    _colorIndex = (_colorIndex + 1) % _flashColors.count;
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    // Không làm gì, frame được mediaserverd hook trực tiếp
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    _previewLayer.frame = self.view.bounds;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

@end
