//
//  MCTDrawerViewController.h
//  WCM-DevKit1
//
//  Created by Joel Garrett on 7/16/14.
//  Copyright (c) 2014 Microchip Technology Inc. and its subsidiaries.
//
//  You may use this software and any derivatives exclusively with Microchip products.
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

#import <UIKit/UIKit.h>

extern NSString *const MCTDrawerViewControllerWillOpenNotification;
extern NSString *const MCTDrawerViewControllerWillCloseNotification;

@interface MCTDrawerViewController : UIViewController

@property (nonatomic, weak) IBOutlet UIView *backgroundView;
@property (nonatomic, weak) IBOutlet UIView *consoleContainerView;
@property (nonatomic, weak) IBOutlet UIView *contentContainerView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *contentContainerWidthConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *contentContainerLeadingConstraint;
@property (nonatomic, readonly, getter = isSpringAnimating) BOOL springAnimating;
@property (nonatomic, readonly, getter = isDrawerOpen) BOOL drawerOpen;
@property (nonatomic, readwrite) CGFloat maximumDrawerOpenWidth;

- (void)springOpen;
- (void)springClose;

+ (instancetype)sharedDrawerViewController;
+ (void)setSharedDrawerViewController:(MCTDrawerViewController *)viewController;

@end
