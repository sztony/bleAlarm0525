//
//  SecondViewController.h
//  bleAlarm
//
//  Created by Monster on 14-4-18.
//  Copyright (c) 2014年 HYQ. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "searchRadarView.h"
#import "deviceInfo.h"
#import "GlobalHeader.h"
#import "mapViewController.h"
#import "GLIRViewController.h"

@interface SecondViewController : GLIRViewController<deviceInfoDelegate,ConnectionManagerDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate,UIAlertViewDelegate,UITextFieldDelegate,UIGestureRecognizerDelegate>
{
    searchRadarView* _searchView;
    BOOL _openl;
    UIAlertView* _alertView;
    
    UIBarButtonItem* _cameraButton;
    UIBarButtonItem* _dismissButton;
    
    BOOL _canNotice;
    BOOL _canCamera;
    BOOL _canmeraOpen;
    
    NSArray* _areaIndexArray;
    
    UIImagePickerController* cameraVC;
    
    NSTimer* _warmingTimer;
    
    UIAlertView* _alert;
}
@property (weak, nonatomic) IBOutlet UIImageView *radarImagView;

@property (weak, nonatomic) IBOutlet UISlider *slider;
- (IBAction)sliderChange:(UISlider *)sender;

@property (weak, nonatomic) IBOutlet UITextField *deviceNameLabel;

@property (weak, nonatomic) IBOutlet UIImageView *batteryImageView;
@property (weak, nonatomic) IBOutlet UIImageView *singalImageView;

@property (weak, nonatomic) IBOutlet UIButton *findButton;
@property (weak, nonatomic) IBOutlet UILabel *mixLabel;



- (IBAction)findButtonTouch:(UIButton *)sender;


@property (strong, nonatomic) deviceInfo *devInfo;
-(void)setDevInfo:(deviceInfo *)devsInfo;
@end
