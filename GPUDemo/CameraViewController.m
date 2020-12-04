//
//  CameraViewController.m
//  GPUDemo
//
//  Created by TheAppGuruz-New-6 on 28/03/14.
//  Copyright (c) 2014 TheAppGuruz-New-6. All rights reserved.
//

#import "CameraViewController.h"

@interface CameraViewController ()

@end

@implementation CameraViewController
@synthesize btnCapture;
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    //[self initializeCamera];
        // Do any additional setup after loading the view.
    [self initializeCameraFindContour];
}

-(void)initializeCamera
{
    stillCamera=[[GPUImageStillCamera alloc]initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
    stillCamera.outputImageOrientation=UIInterfaceOrientationPortrait;
    
    image=[[GPUImageView alloc]initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width, self.view.frame.size.height)];
    filter=[[GPUImageGrayscaleFilter alloc]init];
    
    [self.view addSubview:image];
    [self.view bringSubviewToFront:btnCapture];
    [stillCamera addTarget:filter];
    [filter addTarget:image];
    [stillCamera startCameraCapture];

}

-(void)initializeCameraFindContour
{
    stillCamera=[[GPUImageStillCamera alloc]initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
    stillCamera.outputImageOrientation=UIInterfaceOrientationPortrait;
    image=[[GPUImageView alloc]initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width, self.view.frame.size.height)];
    [self.view addSubview:image];
    [self.view bringSubviewToFront:btnCapture];
    
    //1. Preprocessing.
    
    hblFilter=[[GPUImageHorizontalBindingFilter alloc]init];
    [stillCamera    addTarget:hblFilter];
    //2. Detection START
    findContour = [[GPUImageFindContourDetector alloc] init];
    [hblFilter addTarget:findContour];
     
    
    //3. blend quads from detected dots
     GPUImageQuadGenerator *quadGenerator = [[GPUImageQuadGenerator alloc] init];
     [quadGenerator forceProcessingAtSize: image.sizeInPixels];
     [findContour setBoxesDetectedBlock:^(GLfloat* boxArray, NSUInteger boxesDetected, CMTime frameTime) {
              [quadGenerator renderQuadsFromArray:boxArray count:boxesDetected frameTime:frameTime];
     }];
    
     GPUImageAlphaBlendFilter *blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
     [blendFilter forceProcessingAtSize:image.sizeInPixels];
     [stillCamera addTarget:blendFilter];//카메라에 뿌리기
     //[findContour addTarget:blendFilter];//전처리에 뿌리기
     [quadGenerator addTarget:blendFilter];
     [blendFilter addTarget:image];
    
     //전처리 뿌리기
     [stillCamera startCameraCapture];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    UIAlertView *alert;
    if (!error)
    {
        alert=[[UIAlertView alloc]initWithTitle:@"Success" message:@"Your image successfully saved to gallary." delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    }
    else
    {
        alert=[[UIAlertView alloc]initWithTitle:@"Error" message:@"Your iamge has not been saved." delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    }
    [alert show];
}

- (IBAction)btnCaptureClicked:(id)sender
{
    [stillCamera capturePhotoAsImageProcessedUpToFilter:filter withCompletionHandler:^(UIImage *processedImage, NSError *error) {
        UIImageWriteToSavedPhotosAlbum(processedImage, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
    }];
}
@end
