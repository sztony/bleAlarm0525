//
//  FirstViewController.h
//  bleAlarm
//
//  Created by Monster on 14-4-18.
//  Copyright (c) 2014年 HYQ. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "findTableViewCell.h"
#import "GlobalHeader.h"
#import "addedDeviceTableViewCell.h"
#import "newDeviceTableViewCell.h"
#import "SecondViewController.h"

@interface FirstViewController : UIViewController<UITableViewDataSource,UITableViewDelegate,ConnectionManagerDelegate,deviceInfoDelegate,addedDeviceTableViewCellDelegate,newDeviceTableViewCellDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate>
{
    NSTimer* searchAnimationTimer;
    NSMutableArray* addedDeviceArray;
    NSMutableArray* newDeviceArray;
    
    addedDeviceTableViewCell* addedCell;
    newDeviceTableViewCell* newCell;
    
    UIImagePickerController *cameraVC;
    NSTimer* _ldTimer;
    NSUInteger _ldAnimationIndex;
}

@property (strong, nonatomic) deviceInfo *devInfo;
@property (weak, nonatomic) IBOutlet UIImageView *animImageView;

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;



@property (nonatomic, retain)NSMutableArray* devicesArray;

@end
