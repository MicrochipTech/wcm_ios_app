//
//  MCTConsoleCell.m
//  WCM-DevKit1
//
//  Created by Joel Garrett on 7/30/14.
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

#import "MCTConsoleCell.h"

@implementation MCTConsoleCell

- (void)awakeFromNib
{   
    MCTAppearance *appearance = [MCTAppearance appearance];
    [self setBackgroundColor:appearance.primaryTintColor];
    UIView *backgroundView = [UIView new];
    [backgroundView setBackgroundColor:appearance.primaryTintColor];
    [self setBackgroundView:backgroundView];
    
    UIView *selectedBackgroundView = [UIView new];
    UIColor *selectedColor = appearance.secondaryBackgroundViewColor;
    selectedColor = [selectedColor colorWithAlphaComponent:0.05];
    [selectedBackgroundView setBackgroundColor:selectedColor];
    [self setSelectedBackgroundView:selectedBackgroundView];
    
    [[self requestLabel] setTextColor:UIColor.whiteColor];
    [[self responseLabel] setTextColor:UIColor.lightGrayColor];
    [[self responseLabel] setFont:appearance.consoleFont];
    
    UIImage *image = [UIImage imageNamed:@"img_circle_orange"];
    image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [[self statusImageView] setImage:image];
    
    [self setSeparatorInset:UIEdgeInsetsZero];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [[self requestLabel] setText:nil];
    [[self responseLabel] setText:nil];
    [self setEditing:NO animated:NO];
}

@end
