//
//  MCTDeviceManager.m
//  WCM-DevKit1
//
//  Created by Joel Garrett on 7/29/14.
//  Copyright (c) 2014 Microchip Technology Inc. and its subsidiaries. All rights reserved.
//
//  THIS SOFTWARE IS SUPPLIED BY MICROCHIP "AS IS". NO WARRANTIES, WHETHER EXPRESS,
//  IMPLIED OR STATUTORY, APPLY TO THIS SOFTWARE, INCLUDING ANY IMPLIED WARRANTIES
//  OF NON-INFRINGEMENT, MERCHANTABILITY, AND FITNESS FOR A PARTICULAR PURPOSE, OR
//  ITS INTERACTION WITH MICROCHIP PRODUCTS, COMBINATION WITH ANY OTHER PRODUCTS, OR
//  USE IN ANY APPLICATION.
//
//  IN NO EVENT WILL MICROCHIP BE LIABLE FOR ANY INDIRECT, SPECIAL, PUNITIVE,
//  INCIDENTAL OR CONSEQUENTIAL LOSS, DAMAGE, COST OR EXPENSE OF ANY KIND WHATSOEVER
//  RELATED TO THE SOFTWARE, HOWEVER CAUSED, EVEN IF MICROCHIP HAS BEEN ADVISED OF
//  THE POSSIBILITY OR THE DAMAGES ARE FORESEEABLE. TO THE FULLEST EXTENT ALLOWED
//  BY LAW, MICROCHIP'S TOTAL LIABILITY ON ALL CLAIMS IN ANY WAY RELATED TO THIS
//  SOFTWARE WILL NOT EXCEED THE AMOUNT OF FEES, IF ANY, THAT YOU HAVE PAID DIRECTLY
//  TO MICROCHIP FOR THIS SOFTWARE.
//
//  MICROCHIP PROVIDES THIS SOFTWARE CONDITIONALLY UPON YOUR ACCEPTANCE OF THESE
//  TERMS.
//

#import "MCTDeviceManager.h"
#import "MCTDevice.h"
#import "MCTRequest.h"

@interface MCTDeviceManager ()

@property (nonatomic, readwrite) MCTDeviceManagerState state;
@property (nonatomic, strong, readwrite) MCTDevice *connectedDevice;
@property (nonatomic, strong) NSString *responseHash;
@property (nonatomic, weak) NSURLSessionDataTask *sessionDataTask;
@property (nonatomic, weak) NSTimer *pollingTimer;

@end

@implementation MCTDeviceManager

- (void)dealloc
{
    [[self pollingTimer] invalidate];
    [[self sessionDataTask] cancel];
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        [self setState:MCTDeviceManagerStateReady];
    }
    return self;
}

#pragma mark - Notify delegate

- (void)notifyDelegateOfStateChange
{
    if (self.delegate)
    {
        [[self delegate] deviceManagerDidUpdateState:self];
    }
}

- (void)notifyDelegateDeviceConnected:(MCTDevice *)device error:(NSError *)error
{
    if (self.delegate)
    {
        if (error)
        {
            if ([[self delegate] respondsToSelector:@selector(deviceManager:didFailToConnectDevice:)])
            {
                [[self delegate] deviceManager:self didFailToConnectDevice:error];
            }
        }
        else
        {
            if ([[self delegate] respondsToSelector:@selector(deviceManager:didConnectDevice:)])
            {
                [[self delegate] deviceManager:self didConnectDevice:device];
            }
        }
        
    }
}

#pragma mark - Device connect

- (void)connectDevice:(MCTDevice *)device
{
    NSParameterAssert(device);
    [self requestDeviceStatus:device];
}

#pragma mark - Poll device status

- (void)setShouldPollDeviceForUpdates:(BOOL)shouldPollDeviceForUpdates
{
    _shouldPollDeviceForUpdates = shouldPollDeviceForUpdates;
    if (shouldPollDeviceForUpdates &&
        self.connectedDevice != nil &&
        self.pollingTimer == nil)
    {
        [self startPolling];
    }
}

// Starts the polling timer
- (void)startPolling
{
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.125
                                                      target:self
                                                    selector:@selector(scheduledTimerUpdate:)
                                                    userInfo:nil
                                                     repeats:YES];
    [self setPollingTimer:timer];
}

/**
 *  Handles the fire event for the polling timer.
 *  Each event the polling preference is evaluated
 *  along with any pending data tasks.
 *
 *  @param timer the polling timer
 */
- (void)scheduledTimerUpdate:(NSTimer *)timer
{
    if (self.shouldPollDeviceForUpdates == NO)
    {
        [timer invalidate];
    }
    else if (self.sessionDataTask == nil)
    {
        [self processPendingChangesOrRequestStatus];
    }
}

/**
 *  Checks the connected device for changes. If
 *  changes exist they are processed pausing
 *  further status requests. On successful
 *  submission of changes status requests are
 *  resumed.
 */
- (void)processPendingChangesOrRequestStatus
{
    if (self.connectedDevice.hasChanges)
    {
        [self sendDeviceStatus:self.connectedDevice];
    }
    else
    {
        [self requestDeviceStatus:self.connectedDevice];
    }
}

#pragma mark - Request device status

/**
 *  Requests the current status of the provided
 *  device. On success the status of the manager
 *  is changed to connected if polling has not
 *  been started. An assertion is raised if the
 *  provided device does not have a UUID.
 *
 *  @param device the device
 */
- (void)requestDeviceStatus:(MCTDevice *)device
{
    NSParameterAssert(device);
    NSParameterAssert(device.UUID);
    if (self.state == MCTDeviceManagerStateReady ||
        self.state == MCTDeviceManagerStateConnected)
    {
        MCTRequest *request = [MCTRequest requestWithMethod:MCTRequestMethodGET
                                                  URLString:@"json_wcm_get_status.php"
                                                 parameters:@{@"uuid": device.UUID}];
        
        __weak MCTDeviceManager *__weak_self = self;
        NSURLSessionDataTask *task = nil;
        task = [request performRequestWithHandler:^(id responseObject, MCTRequestSummary *requestSummary) {
            
            if (requestSummary.responseError)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [__weak_self handleFailedDeviceFetch:requestSummary
                                               forDevice:device];
                    
                });
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [__weak_self handleSuccessfulStatusRequest:responseObject
                                                requestSummary:requestSummary
                                                     forDevice:device];
                    
                });
            }
            
        }];
        [self setSessionDataTask:task];
    }
}

/**
 *  Handles successful status requests. If the
 *  returned status hash has changed the request
 *  summary is cached for display in the app's
 *  console.
 *
 *  @param responseObject the device attributes
 *  @param requestSummary the request summary
 *  @param device         the device
 */
- (void)handleSuccessfulStatusRequest:(NSDictionary *)responseObject
                       requestSummary:(MCTRequestSummary *)requestSummary
                            forDevice:(MCTDevice *)device
{
    if (self.connectedDevice == nil)
    {
        [device updateWithAttributes:responseObject];
        [self setConnectedDevice:device];
        [self setState:MCTDeviceManagerStateConnected];
        [self notifyDelegateOfStateChange];
        [self notifyDelegateDeviceConnected:device error:nil];
        if (self.shouldPollDeviceForUpdates)
        {
            [self startPolling];
        }
    }
    else if (![[requestSummary responseHash] isEqualToString:self.responseHash])
    {
        [self setResponseHash:requestSummary.responseHash];
        [device updateWithAttributes:responseObject];
        [requestSummary saveSummary];
    }
    [self setSessionDataTask:nil];
}

/**
 *  Handles failed status requests. The summary
 *  is cached for display in the app's console.
 *  The manager's state is update to reflect the
 *  failure and the delegate is notified.
 *
 *  @param requestSummary the request summary
 *  @param device         the device
 */
- (void)handleFailedDeviceFetch:(MCTRequestSummary *)requestSummary
                      forDevice:(MCTDevice *)device
{
    [requestSummary saveSummary];
    [self setSessionDataTask:nil];
    if (requestSummary.responseError.code != -999)
    {
        [self setState:MCTDeviceManagerStateError];
        [self notifyDelegateOfStateChange];
        [self notifyDelegateDeviceConnected:device
                                      error:requestSummary.responseError];
    }
    else
    {
        [self setState:MCTDeviceManagerStateReady];
        [self notifyDelegateOfStateChange];
    }
}

#pragma mark - Send device status

/**
 *  Sends status updates for the provided
 *  device.
 *
 *  @param device the device
 */
- (void)sendDeviceStatus:(MCTDevice *)device
{
    NSParameterAssert(device);
    NSParameterAssert(device.UUID);
    if (self.state == MCTDeviceManagerStateReady ||
        self.state == MCTDeviceManagerStateConnected)
    {
        NSDictionary *parameters = [device attributeDictionary];
        MCTRequest *request = [MCTRequest requestWithMethod:MCTRequestMethodPOST
                                                  URLString:@"json_wcm_post_status.php"
                                                 parameters:parameters];
        
        __weak MCTDeviceManager *__weak_self = self;
        NSURLSessionDataTask *task = nil;
        task = [request performRequestWithHandler:^(id responseObject, MCTRequestSummary *requestSummary) {
            
            if (requestSummary.responseError)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [__weak_self handleFailedDeviceSend:requestSummary
                                              forDevice:device];
                    
                });
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [__weak_self handleSuccessfulStatusSend:responseObject
                                             requestSummary:requestSummary
                                                  forDevice:device];
                    
                });
            }
            
        }];
        [self setSessionDataTask:task];
    }
}

/**
 *  Handles successful status sends. The request
 *  summary is cached for display in the app's
 *  console. The pending changes are then cleared.
 *
 *  @param responseObject the device attributes
 *  @param requestSummary the request summary
 *  @param device         the device
 */
- (void)handleSuccessfulStatusSend:(NSDictionary *)responseObject
                    requestSummary:(MCTRequestSummary *)requestSummary
                         forDevice:(MCTDevice *)device
{
    [requestSummary saveSummary];
    [device clearChanges];
}

/**
 *  Handles failed status sends. The request
 *  summary is cached for display in the app's
 *  console. The pending changes are then cleared
 *  and the manager's state is update to reflect
 *  the failure.
 *
 *  @param requestSummary the request summary
 *  @param device         the device
 */
- (void)handleFailedDeviceSend:(MCTRequestSummary *)requestSummary forDevice:(MCTDevice *)device
{
    [requestSummary saveSummary];
    [device clearChanges];
    [self setSessionDataTask:nil];
    if (requestSummary.responseError.code != -999)
    {
        [self setState:MCTDeviceManagerStateError];
        [self notifyDelegateOfStateChange];
    }
    else
    {
        [self setState:MCTDeviceManagerStateReady];
        [self notifyDelegateOfStateChange];
    }
}

#pragma mark - Cancel device connection

- (void)cancelDeviceConnection
{
    if (self.state == MCTDeviceManagerStateConnected ||
        self.state == MCTDeviceManagerStateError)
    {
        [[self pollingTimer] invalidate];
        [[self sessionDataTask] cancel];
        [self setSessionDataTask:nil];
        [self setResponseHash:nil];
        [self setConnectedDevice:nil];
        [self setState:MCTDeviceManagerStateReady];
        [self notifyDelegateOfStateChange];
    }
}

@end
