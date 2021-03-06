//
//  ConnectionManager.m
//  bleAlarm
//
//  Created by Monster on 14-4-18.
//  Copyright (c) 2014年 HYQ. All rights reserved.
//

#import "ConnectionManager.h"

#define TRANSFER_SERVICE_UUID @"1802"
#define TRANSFER_SERVICE_DEVICEINFO_UUID @"180A"
#define TRANSFER_CHARACTERISTIC_UUID    @"2A06"
#define TRANSFER_CHARACTERISTIC_DEVICEINFO1_UUID    @"2A29"
#define TRANSFER_CHARACTERISTIC_DEVICEINFO2_UUID    @"2A24"
#define TRANSFER_CHARACTERISTIC_DEVICEINFO3_UUID    @"2A25"
#define TRANSFER_BATTERY_UUID  @"180F"
@implementation ConnectionManager
@synthesize manager;

void (^block)(CTCall*) = ^(CTCall* call) {
    
    NSLog(@"FUCKFUCKFUCKFUCKFUCKFUCKFUCK%@", call.callState);
    [AppDelegate App].callStateStr = call.callState;
};

static ConnectionManager *sharedConnectionManager;

+ (ConnectionManager*) sharedInstance
{
    if (sharedConnectionManager == nil)
    {
        sharedConnectionManager = [[ConnectionManager alloc]initWithDelegate:nil];
    }
    return sharedConnectionManager;
}
- (ConnectionManager*) initWithDelegate:(id<ConnectionManagerDelegate>) delegate
{
    if (self = [super init])
    {
        _delegate = delegate;
        
        callCenter1 = [[CTCallCenter alloc] init];
        callCenter1.callEventHandler = nil;
        
        _diffSign = NO;
        _dialingGapTimer = [NSTimer timerWithTimeInterval:3.0 target:self selector:@selector(test) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop]addTimer:_dialingGapTimer forMode:NSRunLoopCommonModes];
        
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        [_locationManager startUpdatingLocation];
        
//        NSString *soundPath = [[NSBundle mainBundle] pathForResource:@"alertsound" ofType:@"wav"];
//        AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:soundPath], &_soundID);
        
        _localAskFoundNotice = [[UILocalNotification alloc] init];
        
        
        manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
        
        _peripheralDictionary = [NSMutableDictionary dictionary];
        _characteristicDictionary = [NSMutableDictionary dictionary];
        
        _addedDeviceArray = [NSMutableArray array];
        _newsDeviceArray = [NSMutableArray array];
        
        _deviceManagerDictionary = [NSMutableDictionary dictionary];
        
        _finePhoneOpen = NO;
        warningStrength = 0;
        warningStrengthTemp = 0;
        _indexRSSI = 0;
        _isOutWarning = NO;
        NSData* aData = [USER_DEFAULT objectForKey:KEY_DEVICELIST_INFO];
        _addedDeviceArray = [NSKeyedUnarchiver unarchiveObjectWithData:aData];
        if (_addedDeviceArray == nil) {
            _addedDeviceArray = [NSMutableArray array];
        }else{
            
            for (deviceInfo* device in _addedDeviceArray) {
                [_deviceManagerDictionary setObject:device forKey:device.identifier];
                
                device.connected = NO;
                
            }
        }
        
        warningStrengthCheckTimer = [NSTimer timerWithTimeInterval:4.0f target:self selector:@selector(outOfRangeWarning) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop]addTimer:warningStrengthCheckTimer forMode:NSDefaultRunLoopMode];
        
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(deviceDismissInfoChange) name:NSNotificationCenter_dismissRecordChange object:nil];
    }
    return self;
}

-(void)test
{
    NSSet* callSet1 = callCenter1.currentCalls;
    NSSet* callSet2 = callCenter1.currentCalls;
    NSLog(@"callset1:%@",callSet1);
    NSLog(@"callset2:%@",callSet2);
    NSArray *array = [callSet1 allObjects];
    if (array.count) {
        CTCall* ctCall = [array objectAtIndex:0];
        [[ConnectionManager sharedInstance]scheduleCallingState:ctCall.callState];
    }else{
        
        callSet2 = callCenter2.currentCalls;
        array = [callSet2 allObjects];
        CTCall* ctCall = [array objectAtIndex:0];
        [[ConnectionManager sharedInstance]scheduleCallingState:ctCall.callState];
    }
    
    
}
-(void)dealloc
{
    [[NSNotificationCenter defaultCenter]removeObserver:self name:NSNotificationCenter_dismissRecordChange object:nil];
}

-(void)deviceDismissInfoChange
{
    [USER_DEFAULT removeObjectForKey:KEY_DEVICELIST_INFO];
    NSData* aDate = [NSKeyedArchiver archivedDataWithRootObject:_addedDeviceArray];
    [USER_DEFAULT setObject:aDate forKey:KEY_DEVICELIST_INFO];
    [USER_DEFAULT synchronize];
}
#pragma mark -scan
- (void) startScanForDevice
{
    NSDictionary* scanOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
    
    // Make sure we start scan from scratch
    [manager stopScan];
    
    [manager scanForPeripheralsWithServices:nil options:scanOptions];
}

- (void) stopScanForDevice
{
    [manager stopScan];
}

#pragma mark - alarmFuc
-(void)outOfRangeWarning
{
    if (!checkDevice) {
        return;
    }
    if ([checkDevice.warningStrength floatValue] > warningStrength) {
        if (_isOutWarning) {
            if (warningStrength <= 80) {
                _isOutWarning = NO;
                [[ConnectionManager sharedInstance]findDevice:checkDevice.identifier isOn:NO];
                [self.delegate didOutofRangWithDevice:checkDevice on:NO];
            }
        }
        return;
    }
    NSLog(@"checkDevice: %f   8888:%f",[checkDevice.warningStrength floatValue],warningStrength);
    if (1){//checkDevice.open) {
        if (_isOutWarning) {
            return;
        }
        _isOutWarning = YES;
        [[ConnectionManager sharedInstance]findDevice:checkDevice.identifier isOn:YES];
        [self.delegate didOutofRangWithDevice:checkDevice on:YES];
        [self scheduleOutOfRangeNotification:checkDevice];
        
        [checkDevice.locationCoordArray addObject:[deviceDisconnectInfo shareInstanceWithLocation:_location date:[NSDate date]]];
        [[NSNotificationCenter defaultCenter]postNotificationName:NSNotificationCenter_dismissRecordChange object:nil];
    }
}
#pragma mark - fuction

- (void) removeDevice:(deviceInfo*)device
{
    device.isUserForceDisconnect = YES;//用户在列表删除  则以后不再连接
    NSLog(@"removeDevice: device : %@,,[_peripheralDictionary objectForKey:device.identifier]:%@",device.idString,[_peripheralDictionary objectForKey:device.identifier]);
    if (device.connected) {
        if ([_peripheralDictionary objectForKey:device.identifier]) {
            [self.manager cancelPeripheralConnection:[_peripheralDictionary objectForKey:device.identifier]];
            [self.peripheralManager removeAllServices];
            [self.peripheralManager stopAdvertising];
        }
    }
}
-(BOOL)findDevice:(NSString*)name isOn:(BOOL)on
{
    BOOL result = NO;
    uint8_t val;
    if (on) {
        val = 2;
    }else{
        val = 0;
    }
    NSData* valData = [NSData dataWithBytes:(void*)&val length:sizeof(val)];
    
    CBPeripheral* peripheralss = [_peripheralDictionary objectForKey:name];
    CBCharacteristic* characterisiticss = [_characteristicDictionary objectForKey:name];
    
    if (peripheralss && characterisiticss) {
        [peripheralss writeValue:valData forCharacteristic:characterisiticss type:CBCharacteristicWriteWithoutResponse];
        result = YES;
    }
    return result;
}
//来电提示操作
-(void)reminderDeviceStr:(NSString*)str on:(BOOL)on
{
    uint8_t val;
    if (on) {
        if (_dialingSign == NO) {
            val = 2;
            _dialingSign = YES;
        }else{
            val = 2;
            _dialingSign = NO;
        }
    }else{
        val = 0;
    }
    
    NSData* valData = [NSData dataWithBytes:(void*)&val length:sizeof(val)];
    
    CBPeripheral* peripheralss = [_peripheralDictionary objectForKey:str];
    CBCharacteristic* characterisiticss = [_characteristicDictionary objectForKey:str];
    
    if (peripheralss && characterisiticss) {
        [peripheralss writeValue:valData forCharacteristic:characterisiticss type:CBCharacteristicWriteWithoutResponse];
        NSLog(@"reminderDevice  ++++++");
    }
}
-(void)reminderDevice:(NSTimer*)useinfo
{
    NSString* name = [useinfo userInfo];
    uint8_t val;
    if (_dialingSign == NO) {
        val = 2;
        _dialingSign = YES;
    }else{
        val = 0;
        _dialingSign = NO;
    }
    NSData* valData = [NSData dataWithBytes:(void*)&val length:sizeof(val)];
    
    CBPeripheral* peripheralss = [_peripheralDictionary objectForKey:name];
    CBCharacteristic* characterisiticss = [_characteristicDictionary objectForKey:name];
    
    if (peripheralss && characterisiticss) {
        [peripheralss writeValue:valData forCharacteristic:characterisiticss type:CBCharacteristicWriteWithoutResponse];
        NSLog(@"reminderDevice  ++++++");
    }
}

-(void)scheduleOutOfRangeNotification:(deviceInfo*)device
{
    if (!_localOutOfRangeNotice) {
        _localOutOfRangeNotice = [[UILocalNotification alloc] init];
    }
    if ([[UIApplication sharedApplication]applicationState] != UIApplicationStateBackground) {
        return;
    }
    _localOutOfRangeNotice.applicationIconBadgeNumber = 1;
    _localOutOfRangeNotice.fireDate = [NSDate dateWithTimeIntervalSinceNow:0];
    _localOutOfRangeNotice.timeZone = [NSTimeZone defaultTimeZone];
    _localOutOfRangeNotice.soundName = @"4031.wav";
    _localOutOfRangeNotice.repeatInterval = NSDayCalendarUnit;
    
    _localOutOfRangeNotice.alertBody = [NSString stringWithFormat:@"%@%@",[NSString deviceNameWithDevice:device], NSLocalizedString(@"已超出范围", nil)];
    
    [[UIApplication sharedApplication] presentLocalNotificationNow:_localOutOfRangeNotice];
}

-(void)scheduleAskFoundNotification:(deviceInfo*)device
{
    if (_localAskFoundNotice) {
        [[UIApplication sharedApplication]cancelLocalNotification:_localAskFoundNotice];
    }
    if ([[UIApplication sharedApplication]applicationState] != UIApplicationStateBackground) {
        return;
    }
    _localAskFoundNotice.applicationIconBadgeNumber = 1;
    _localAskFoundNotice.fireDate = [NSDate dateWithTimeIntervalSinceNow:2];
    _localAskFoundNotice.timeZone = [NSTimeZone defaultTimeZone];
    _localAskFoundNotice.soundName = @"4031.wav";
    _localAskFoundNotice.repeatInterval = NSDayCalendarUnit;
    
    _localAskFoundNotice.alertBody = [NSString stringWithFormat:@"%@%@",[NSString deviceNameWithDevice:device],NSLocalizedString(@"想要找到你", ni)];
    
    [[UIApplication sharedApplication] presentLocalNotificationNow:_localAskFoundNotice];
}
-(void)scheduleCallingState:(NSString*)stateStr
{
    for (deviceInfo* added in _addedDeviceArray) {
        if (!added.open) {
            return;
        }
        if ([stateStr isEqualToString:CTCallStateDialing]) {
//            _dialingGapTimer = [NSTimer timerWithTimeInterval:0.3 target:self selector:@selector(reminderDevice:) userInfo:added.identifier repeats:YES];
//            [[NSRunLoop currentRunLoop]addTimer:_dialingGapTimer forMode:NSDefaultRunLoopMode];
            [self reminderDeviceStr:added.identifier on:NO];
        }else if([stateStr isEqualToString:CTCallStateIncoming]) {
//            _dialingGapTimer = [NSTimer timerWithTimeInterval:0.5 target:self selector:@selector(reminderDevice:) userInfo:added.identifier repeats:YES];
//            [[NSRunLoop currentRunLoop]addTimer:_dialingGapTimer forMode:NSDefaultRunLoopMode];
            [self reminderDeviceStr:added.identifier on:YES];
        }else if([stateStr isEqualToString:CTCallStateConnected]) {
//            _dialingGapTimer = [NSTimer timerWithTimeInterval:0.3 target:self selector:@selector(reminderDevice:) userInfo:added.identifier repeats:YES];
//            [[NSRunLoop currentRunLoop]addTimer:_dialingGapTimer forMode:NSDefaultRunLoopMode];
            [self reminderDeviceStr:added.identifier on:NO];
        }else if([stateStr isEqualToString:CTCallStateDisconnected]) {
            [self reminderDeviceStr:added.identifier on:NO];
            [AppDelegate App].callStateStr = nil;
        }
    }
    
}
#pragma mark - perprial delegate
#pragma mark - ble delegates
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripherals
{
    // Opt out from any other state
    if (peripherals.state != CBPeripheralManagerStatePoweredOn) {
        return;
    }
    
    // We're in CBPeripheralManagerStatePoweredOn state...
    NSLog(@"self.peripheralManager powered on.");
    
    // Start with the CBMutableCharacteristic
    self.transferCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]
                                                                     properties:CBCharacteristicPropertyWriteWithoutResponse
                                                                          value:nil
                                                                    permissions:CBAttributePermissionsReadable|CBAttributePermissionsWriteable];
    
    //    CBMutableCharacteristic* transferCharacteristicOne = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:@"2A07"]
    //                                                                properties:CBCharacteristicPropertyRead|CBCharacteristicPropertyWrite
    //                                                                     value:nil
    //                                                               permissions:CBAttributePermissionsReadable];
    //    CBMutableCharacteristic* transferCharacteristicTwo = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:@"2A08"]
    //                                                                                         properties:CBCharacteristicPropertyRead|CBCharacteristicPropertyWrite
    //                                                                                              value:nil
    //                                                                                        permissions:CBAttributePermissionsReadable];
    
    // Then the service
    CBMutableService *transferService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]
                                                                       primary:YES];
    
    // Add the characteristic to the service
    transferService.characteristics = @[self.transferCharacteristic];
    
    // And add it to the peripheral manager
    [self.peripheralManager addService:transferService];
    
    [self.peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]] }];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests
{
    NSLog(@"didReceiveWriteRequests");
    CBATTRequest* request = (CBATTRequest*)[requests objectAtIndex:0];
    deviceInfo* device = [_deviceManagerDictionary objectForKey:[request.central.identifier UUIDString]];
    if (device) {
        CBATTRequest* request = [requests objectAtIndex:0];
        int someInt = 0;
        [request.value getBytes:&someInt length:2];
        if (_finePhoneOpen) {
            _finePhoneOpen = NO;
            [self.delegate didDeviceWanaFindMe:device on:NO];
        }else{
            _finePhoneOpen = YES;
            [self.delegate didDeviceWanaFindMe:device on:YES];
        }
        
        [self scheduleAskFoundNotification:device];
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request
{
    NSLog(@"didReceiveReadRequest :%@",request);
}

- (void)peripheralManager:(CBPeripheralManager *)arg_peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"central:%@,characteristic:%@,%d,%@",central,characteristic.UUID,characteristic.properties,characteristic.value);
    
    uint8_t val = 2;
    NSData* valData = [NSData dataWithBytes:(void*)&val length:sizeof(val)];
    [arg_peripheral updateValue:valData forCharacteristic:characteristic onSubscribedCentrals:@[central]];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central unsubscribed from characteristic");
}

#pragma mark - center delegate
-(void)centralManagerDidUpdateState:(CBCentralManager *)central{
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
        {
            if ([central state] == CBCentralManagerStatePoweredOn)
            {
                [_delegate isBluetoothEnabled:YES];
            }
            else
            {
                [_delegate isBluetoothEnabled:NO];
            }
            
            NSLog(@"CBCentralManagerStatePoweredOn");
        }
            break;
        case CBCentralManagerStatePoweredOff:
            NSLog(@"CBCentralManagerStatePoweredOff");
            break;
        case CBCentralManagerStateUnsupported:
            NSLog(@"CBCentralManagerStateUnsupported");
            break;
        case CBCentralManagerStateResetting:
            NSLog(@"CBCentralManagerStateResetting");
            break;
        case CBCentralManagerStateUnauthorized:
            NSLog(@"CBCentralManagerStateUnauthorized");
            break;
        case CBCentralManagerStateUnknown:
            NSLog(@"CBCentralManagerStateUnknown");
            break;
            
        default:
            NSLog(@"CM did Change State");
            
            break;
    }
}

-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)args_peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI{
    
//   NSLog(@"Discovered peripheral, name %@, data: %@, RSSI: %f", [args_peripheral name], advertisementData, RSSI.floatValue);
    
    //屏蔽不可连接设备
    BOOL connectable = [[advertisementData objectForKey:@"kCBAdvDataIsConnectable"]boolValue];
    if (!connectable) {
        return;
    }
    if ([[args_peripheral name] isEqualToString:@"YouNiGe"]) {
        NSString* ss = [advertisementData objectForKey:@"kCBAdvDataManufacturerData"];
        if (!ss) {
            return;
        }
        NSLog(@"11111%@",[[NSString alloc] initWithData:[advertisementData objectForKey:@"kCBAdvDataManufacturerData"] encoding:NSUTF8StringEncoding]);
    }
    
//    //屏蔽已连接设备
//    if ([advertisementData objectForKey:@"kCBAdvDataManufacturerData"]) {
//        return;
//    }
    
    //屏蔽无服务设备
    NSArray *serviceData = [advertisementData objectForKey:@"kCBAdvDataServiceUUIDs"];
    if (!serviceData)
    {
//        NSLog(@"Discovered unknown device, %@", [args_peripheral name]);
        return;
    }
    if (![_peripheralDictionary objectForKey:[args_peripheral.identifier UUIDString]]) {
//        NSLog(@"args_peripheral:%@",args_peripheral);
        
        devInfo = [deviceInfo deviceWithId:args_peripheral.name identifier:[args_peripheral.identifier UUIDString]];
//        [devInfo.locationCoordArray addObject:[deviceDisconnectInfo shareInstanceWithLocation:_location date:[NSDate date]]];
        
        BOOL isFound = NO;
        for (deviceInfo* added in _addedDeviceArray) {
            if ([added.identifier isEqualToString:[args_peripheral.identifier UUIDString]]) {
                isFound = YES;
                [_peripheralDictionary setObject:args_peripheral forKey:[args_peripheral.identifier UUIDString]];
                [manager connectPeripheral:args_peripheral options:nil];
            }
        }
        if (!isFound) {
            for (deviceInfo* newDevice in _newsDeviceArray) {
                if ([newDevice.identifier isEqualToString:[args_peripheral.identifier UUIDString]]) {
                    isFound = YES;
                }
            }
            if (!isFound){
                [_newsDeviceArray addObject:devInfo];
                [_deviceManagerDictionary setObject:devInfo forKey:devInfo.identifier];
                [self.delegate didDiscoverDevice:devInfo];
            }
            
        }
    }
    
}

-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)arg_peripheral error:(NSError *)error{
    NSLog(@"Connecting Fail: %@",error);
    [manager connectPeripheral:arg_peripheral options:nil];
}

-(void)disconnectNotice:(NSTimer*)timer
{
    deviceInfo* device = (deviceInfo*) [timer userInfo];
    [self.delegate didDisconnectWithDevice:device];
    [self scheduleOutOfRangeNotification:device];
    [device.locationCoordArray addObject:[deviceDisconnectInfo shareInstanceWithLocation:_location date:[NSDate date]]];
    
    [[NSNotificationCenter defaultCenter]postNotificationName:NSNotificationCenter_dismissRecordChange object:nil];
}
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)persipheral error:(NSError *)error
{
    NSLog(@"disconnect!!!!  error: %@",error);
    
    
    deviceInfo* device = [_deviceManagerDictionary objectForKey:[persipheral.identifier UUIDString]];
    if (!device||device.isUserForceDisconnect) {
        if (device) {
            [_peripheralDictionary removeObjectForKey:device.identifier];
            [_deviceManagerDictionary removeObjectForKey:device.identifier];
        }
        
        
        
        CBMutableService *transferService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]
                                                                           primary:YES];
        
        // Add the characteristic to the service
        transferService.characteristics = @[self.transferCharacteristic];
        
        // And add it to the peripheral manager
        
//        [self.peripheralManager addService:transferService];
//        
//        [self.peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]] }];
        return;
    }
    
    [manager connectPeripheral:persipheral options:nil];
    if (!device.open) {
//        return;
    }
    device.connected = NO;
    if (device) {
        if (disconnectTimer) {
            return;
        }
        disconnectTimer = [NSTimer timerWithTimeInterval:3.0f target:self selector:@selector(disconnectNotice:) userInfo:device repeats:NO];
        [[NSRunLoop currentRunLoop]addTimer:disconnectTimer forMode:NSDefaultRunLoopMode];
    }
    
}

-(void)peripheralDidUpdateRSSI:(CBPeripheral *)arg_peripheral error:(NSError *)error
{
//    NSLog(@"[[[[[[[[[[[[[[[peripheral.ddd:%f]]]]]]]]]]]]]]]",[arg_peripheral.RSSI floatValue]);
    checkDevice = [_deviceManagerDictionary objectForKey:[arg_peripheral.identifier UUIDString]];
    if (checkDevice) {
        
        _peripheral = arg_peripheral;
        checkRssiTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(updateRSSIAction) userInfo:nil repeats:NO];
        [[NSRunLoop currentRunLoop]addTimer:checkRssiTimer forMode:NSDefaultRunLoopMode];
        
        checkDevice.signalStrength = arg_peripheral.RSSI;
        
        NSLog(@"peripheralDidUpdateRSSI:%f",[arg_peripheral.RSSI floatValue]);
        
        CGFloat meter = (-1)*[arg_peripheral.RSSI floatValue];
        
        if (meter < 30.0f) {
            meter = 31.0f;
        }
        if (warningStrength == 0) {
            warningStrength = meter;
        }
        
        if (_indexRSSI < 10) {
            _indexRSSI ++;
            if (warningStrengthTemp == 0) {
                warningStrengthTemp = meter;
            }
            
            if (warningStrengthTemp > meter) {
                warningStrengthTemp = meter;
            }
            
//            if (meter > warningStrength+10 && _diffSign == NO ) {
//                _diffSign = YES;
//                return;
//            }
//            //不停取均值
//            warningStrength = (warningStrength + meter)/2;
            return;
        }
        warningStrength = warningStrengthTemp;
        warningStrengthTemp = 0;
        _indexRSSI = 0;
        _diffSign = NO;
        //不停取均值
        warningStrength = (warningStrength + meter)/2;
        
        [checkDevice.delegate didUpdateData:checkDevice];
        NSLog(@"checkDevice:%f",[checkDevice.signalStrength floatValue]);
    }
}

-(void)updateRSSIAction
{
    [_peripheral readRSSI];
}

-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)args_peripheral
{
    [args_peripheral setDelegate:self];
    [args_peripheral readRSSI];
    [args_peripheral discoverServices:nil];
}

-(void)peripheral:(CBPeripheral *)args_peripheral didDiscoverServices:(NSError *)error{
    if (error) {
        NSLog(@"Error discover service: %@",[error localizedDescription]);
        return;
    }
    
    for(CBService *service in args_peripheral.services){
        NSLog(@"Service found with UUID: %@",service.UUID);
        if ([service.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]) {
            [args_peripheral discoverCharacteristics:nil forService:service];
        }else if ([service.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_BATTERY_UUID]]) {
            [args_peripheral discoverCharacteristics:nil forService:service];
        }else if([service.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_SERVICE_DEVICEINFO_UUID]])
            [args_peripheral discoverCharacteristics:nil forService:service];
    }
    
    deviceInfo* device = [_deviceManagerDictionary objectForKey:[args_peripheral.identifier UUIDString]];
    device.connected = YES;
    [self.delegate didConnectWithDevice:device];
    [disconnectTimer invalidate];
    disconnectTimer = nil;
    
}

-(void)peripheral:(CBPeripheral *)args_peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    
    if (error) {
        NSLog(@"Error discover Character");
        //;
        return;
    }
    
    if ([service.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_SERVICE_DEVICEINFO_UUID]])
    {
        for (CBCharacteristic *aChar in service.characteristics)
        {
            NSLog(@"Characteristic test FOUND: %@ %@ %u",aChar.value,aChar.UUID,aChar.properties);
            
            /* Set notification on heart rate measurement */
            [args_peripheral readValueForCharacteristic:aChar];
        }
    }else if ([service.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]])
    {
        for (CBCharacteristic *aChar in service.characteristics)
        {
            NSLog(@"Characteristic FOUND: %@ %@ %u",aChar.value,aChar.UUID,aChar.properties);
            
            /* Set notification on heart rate measurement */
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]])
            {
                [args_peripheral setNotifyValue:YES forCharacteristic:aChar];
            }
        }
    }else if ([service.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_BATTERY_UUID]])
    {
        for (CBCharacteristic *aChar in service.characteristics)
        {
            NSLog(@"Characteristic FOUND: %@ %@ %u",aChar.value,aChar.UUID,aChar.properties);
            _batteryUUID = aChar.UUID;
            [args_peripheral readValueForCharacteristic:aChar];
        }
    }
}
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        return;
    }
    NSLog(@"Characteristic value : %@ with ID %@", characteristic.value, characteristic.UUID);
    NSLog(@"Characteristic value111 : %@ with ID %@", [[NSString alloc] initWithData:characteristic.value encoding:NSASCIIStringEncoding], characteristic.UUID);
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_DEVICEINFO1_UUID]]) {
        NSString* ManufacturerStr = [[NSString alloc] initWithData:characteristic.value encoding:NSASCIIStringEncoding];
        NSLog(@"Characteristic value1 : %@ with ID %@", ManufacturerStr, characteristic.UUID);
        if (![ManufacturerStr isEqualToString:@"Dialog Semi"]&&![ManufacturerStr isEqualToString:@"Dialog-BFU"]) {
            [manager cancelPeripheralConnection:peripheral];
        }
    }
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_DEVICEINFO2_UUID]]) {
        NSString* ManufacturerStr = [[NSString alloc] initWithData:characteristic.value encoding:NSASCIIStringEncoding];
        NSLog(@"Characteristic value1 : %@ with ID %@", ManufacturerStr, characteristic.UUID);
        if (![ManufacturerStr isEqualToString:@"DA14580"]){//&&![ManufacturerStr isEqualToString:@"Dialog-BFU"]) {
            [manager cancelPeripheralConnection:peripheral];
        }
    }
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_DEVICEINFO3_UUID]]) {
        NSString* ManufacturerStr = [[NSString alloc] initWithData:characteristic.value encoding:NSASCIIStringEncoding];
        NSLog(@"Characteristic value1 : %@ with ID %@", ManufacturerStr, characteristic.UUID);
        if (![ManufacturerStr isEqualToString:@"v_3.0.2.139"]&&![ManufacturerStr isEqualToString:@"v_3.0.2.139"]) {
            [manager cancelPeripheralConnection:peripheral];
        }
    }
    
    if ([characteristic.UUID isEqual:_batteryUUID]) {
        checkDevice = [_deviceManagerDictionary objectForKey:[peripheral.identifier UUIDString]];
        
        NSString *aString = [NSString stringWithFormat:@"%@",characteristic.value];
        aString = [aString substringFromIndex:1];
        aString = [aString substringToIndex:2];
        CGFloat battery = strtoul([aString UTF8String],0,16);
        if (battery > 100.0f) {
            battery = 100.0f;
        }
        checkDevice.batteryLevel = [NSNumber numberWithFloat:battery];
    }
}

-(int)getRawValue:(Byte)highByte lowByte:(Byte)lowByte{
    
    int hi = (int)highByte;
    int lo = ((int)lowByte) & 0xFF;
    
    int return_value = (hi<<8) | lo;

    return return_value;
}


-(void)peripheral:(CBPeripheral *)args_peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    
    if (error) {
        NSLog(@"didUpdateNotificationStateForCharacteristic error:%@",error);
    }
    NSLog(@"characteristic.UUID:%@  value:%@, characteristic.properties:%d",characteristic.UUID,characteristic.value,characteristic.properties);
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
        [_characteristicDictionary setObject:characteristic forKey:[args_peripheral.identifier UUIDString]];
         [args_peripheral readValueForCharacteristic:characteristic];
    }
}


#pragma mark - CLLocation delegate

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    [_locationManager stopUpdatingLocation];

    _location = newLocation;
//    NSString *strLat = [NSString stringWithFormat:@"%.4f",newLocation.coordinate.latitude];
//    NSString *strLng = [NSString stringWithFormat:@"%.4f",newLocation.coordinate.longitude];
//    NSLog(@"Lat: %@  Lng: %@", strLat, strLng);
    
//    CLLocationCoordinate2D coords = CLLocationCoordinate2DMake(newLocation.coordinate.latitude,newLocation.coordinate.longitude);
//    float zoomLevel = 0.02;
//    MKCoordinateRegion region = MKCoordinateRegionMake(coords,MKCoordinateSpanMake(zoomLevel, zoomLevel));
//    [_mapView setRegion:[_mapView regionThatFits:region] animated:YES];
}
@end
