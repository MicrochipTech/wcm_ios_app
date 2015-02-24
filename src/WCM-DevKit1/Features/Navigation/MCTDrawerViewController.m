//
//  MCTDrawerViewController.m
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

#import "MCTDrawerViewController.h"
#import "MCTAppearance.h"

NSString *const MCTDrawerViewControllerWillOpenNotification = @"MCTDrawerViewControllerWillOpenNotification";
NSString *const MCTDrawerViewControllerWillCloseNotification = @"MCTDrawerViewControllerWillCloseNotification";
static MCTDrawerViewController *_sharedDrawerViewController = nil;

@interface MCTDrawerViewController ()

@property (nonatomic, readwrite, getter = isSpringAnimating) BOOL springAnimating;

@end

@implementation MCTDrawerViewController

+ (instancetype)sharedDrawerViewController
{
    return _sharedDrawerViewController;
}

+ (void)setSharedDrawerViewController:(MCTDrawerViewController *)viewController;
{
    _sharedDrawerViewController = viewController;
}

- (void)awakeFromNib
{
    [self setMaximumDrawerOpenWidth:220.0];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupContentContainerView];
    [self setupEdgeGestureRecognizer];
    
    MCTAppearance *appearance = [MCTAppearance appearance];
    [[self backgroundView] setBackgroundColor:appearance.primaryTextColor];
}

- (void)setupContentContainerView
{
    CALayer *containerLayer = [[self contentContainerView] layer];
    [containerLayer setShadowColor:UIColor.blackColor.CGColor];
    [containerLayer setShadowOffset:CGSizeMake(-1.0, 0.0)];
    [containerLayer setShadowOpacity:0.5];
    
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:containerLayer.bounds];
    [containerLayer setShadowPath:path.CGPath];
}

- (void)setupEdgeGestureRecognizer
{
    SEL selector = @selector(handleEdgePanGestureRecognizer:);
    UIScreenEdgePanGestureRecognizer *recognizer = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self
                                                                                                     action:selector];
    recognizer.edges = UIRectEdgeLeft;
    recognizer.cancelsTouchesInView = YES;
    [[self view] addGestureRecognizer:recognizer];
}

#pragma mark - Gesture handlers

- (void)handleEdgePanGestureRecognizer:(UIScreenEdgePanGestureRecognizer *)recognizer
{
    [self springOpen];
}

#pragma mark - Spring open/close animation and state

- (BOOL)isDrawerOpen
{
    return (self.contentContainerLeadingConstraint.constant != 0.0 &&
            self.isSpringAnimating == NO);
}

- (void)springOpen
{
    if (self.isSpringAnimating == NO)
    {
        NSNotification *notification = [NSNotification notificationWithName:MCTDrawerViewControllerWillOpenNotification
                                                                     object:self];
        [[NSNotificationCenter defaultCenter] postNotification:notification];
        self.contentContainerLeadingConstraint.constant = self.maximumDrawerOpenWidth;
        [self springAnimate];
    }
}

- (void)springClose
{
    if (self.isSpringAnimating == NO)
    {
        NSNotification *notification = [NSNotification notificationWithName:MCTDrawerViewControllerWillCloseNotification
                                                                     object:self];
        [[NSNotificationCenter defaultCenter] postNotification:notification];
        self.contentContainerLeadingConstraint.constant = 0.0;
        [self springAnimate];
    }
}

- (void)springAnimate
{
    [self setSpringAnimating:YES];
    [UIView mct_animateWithLinearSpring:^{
        
        [[self view] layoutIfNeeded];
        
    } completion:^(BOOL finished) {
        
        [self setSpringAnimating:NO];
        
    }];
}

- (BOOL)shouldAutomaticallyForwardAppearanceMethods
{
    return YES;
}

@end
