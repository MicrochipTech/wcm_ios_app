//
//  MCTSettingsViewController.m
//  WCM-DevKit1
//
//  Created by Joel Garrett on 7/14/14.
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

#import "MCTSettingsViewController.h"
#import "MCTAttributionView.h"
#import "MCTSettingsFieldCell.h"
#import "MCTSettingsSwitchCell.h"
#import "MCTStatusFooterView.h"
#import "MCTDeviceManager.h"
#import "MCTDevice.h"
#import "MCTSession.h"

typedef NS_ENUM(NSUInteger, MCTSettingsTableViewSection)
{
    MCTSettingsTableViewSectionServerAddress,
    MCTSettingsTableViewSectionDeviceUUID,
    MCTSettingsTableViewSectionServerTrust,
    MCTSettingsTableViewSectionCount,
};

@interface MCTSettingsViewController () <UIGestureRecognizerDelegate, UITextFieldDelegate, MCTDeviceManagerDelegate>

@property (nonatomic, strong) MCTSettingsFieldCell *serverAddressCell;
@property (nonatomic, strong) MCTSettingsFieldCell *deviceUUIDCell;
@property (nonatomic, strong) MCTSettingsSwitchCell *serverTrustCell;
@property (nonatomic, strong) MCTStatusFooterView *footerView;
@property (nonatomic, strong) MCTDeviceManager *deviceManager;
@property (nonatomic, readwrite, getter = isValidServerAddress) BOOL validServerAddress;
@property (nonatomic, readwrite, getter = isValidDeviceUUID) BOOL validDeviceUUID;

@end

@implementation MCTSettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupTableView];
    [self setupStaticCells];
    [self setupDeviceManager];
}

- (void)setupDeviceManager
{
    MCTDeviceManager *manager = [MCTDeviceManager new];
    [manager setDelegate:self];
    [self setDeviceManager:manager];
}

- (void)setupTableView
{
    MCTAttributionView *backgroundView = [MCTAttributionView mct_instantiateFromNib];
    SEL action = @selector(handleAttributionTapGesture:);
    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                              action:action];
    [gesture setDelegate:self];
    [[self tableView] addGestureRecognizer:gesture];
    [[self tableView] setBackgroundView:backgroundView];
    [[self tableView] setTableFooterView:[UIView new]];
    [[self tableView] registerClass:[UITableViewCell class]
             forCellReuseIdentifier:[UITableViewCell mct_reuseIdentifier]];
    
    MCTStatusFooterView *footerView = [MCTStatusFooterView mct_instantiateFromNib];
    [self setFooterView:footerView];
    [[self tableView] setTableFooterView:footerView];
}

- (void)setupStaticCells
{
    MCTSettingsFieldCell *serverCell = [MCTSettingsFieldCell mct_instantiateFromNib];
    [[serverCell textField] setDelegate:self];
    [[serverCell textField] setPlaceholder:@"http://127.0.0.1"];
    [[serverCell textField] setReturnKeyType:UIReturnKeyNext];
    [self setServerAddressCell:serverCell];
    
    MCTSettingsFieldCell *deviceCell = [MCTSettingsFieldCell mct_instantiateFromNib];
    [[deviceCell textField] setDelegate:self];
    [[deviceCell textField] setPlaceholder:@"9001"];
    [self setDeviceUUIDCell:deviceCell];
    
    MCTSettingsSwitchCell *switchCell = [MCTSettingsSwitchCell mct_instantiateFromNib];
    [[switchCell settingsSwitch] addTarget:self
                                    action:@selector(serverTrustSwitchValueChanged:)
                          forControlEvents:UIControlEventValueChanged];
    [[switchCell titleLabel] setText:@"Ignore Errors"];
    [self setServerTrustCell:switchCell];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateStatusView];
    [self connectDeviceIfReady];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[MCTSession sharedSession] saveSession];
}

#pragma mark - Device connection test

/**
 *  Checks the state of the shared session
 *  and connects to the device matching the
 *  provided UUID. Polling is not enabled
 *  for the settings view as we only need to
 *  determine if the connection works.
 */
- (void)connectDeviceIfReady
{
    // Cancel existing device connection
    if (self.deviceManager.state != MCTDeviceManagerStateReady)
    {
        [[self deviceManager] cancelDeviceConnection];
    }
    
    MCTSession *session = [MCTSession sharedSession];
    if (session.isFullyConfigured)
    {   
        [self updateStatusView];
        MCTDevice *device = [[MCTDevice alloc] initWithUUID:session.deviceUUID];
        [[self deviceManager] connectDevice:device];
    }
}

#pragma mark - Control events

- (IBAction)handleAttributionTapGesture:(UITapGestureRecognizer *)sender
{
    if (self.serverAddressCell.textField.isFirstResponder ||
        self.deviceUUIDCell.textField.isEditing)
    {
        [[[self serverAddressCell] textField] resignFirstResponder];
        [[[self deviceUUIDCell] textField] resignFirstResponder];
    }
    else
    {
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        NSString *platform = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"ipad" : @"iphone";
        
        NSString *URLString = [NSString stringWithFormat:@"http://www.willowtreeapps.com/?utm_source=%@&utm_medium=%@&utm_campaign=attribution",
                               bundleIdentifier, platform];
        NSURL *attributionURL = [NSURL URLWithString:URLString];
        [[UIApplication sharedApplication] openURL:attributionURL];
    }
}

- (IBAction)serverTrustSwitchValueChanged:(UISwitch *)settingsSwitch
{
    MCTSession *session = [MCTSession sharedSession];
    [session setShouldIgnoreServerTrustErrors:settingsSwitch.isOn];
    [self connectDeviceIfReady];
}

#pragma mark - Status view updates

- (void)updateStatusView
{
    MCTAppearance *appearance = [MCTAppearance appearance];
    MCTSession *session = [MCTSession sharedSession];
    if (session.isFullyConfigured == NO)
    {
        [[[self footerView] imageView] setTintColor:appearance.errorStatusColor];
        
        if (self.serverAddressCell.textField.isEditing == NO &&
            self.deviceUUIDCell.textField.isEditing == NO)
        {
            [[[self footerView] textLabel] setText:NSLocalizedString(@"Device Not Configured",
                                                                     @"Device Not Configured")];
        }
        else
        {
            [[[self footerView] textLabel] setText:NSLocalizedString(@"Editing Configuration",
                                                                     @"Editing Configuration")];
        }
    }
    else
    {
        NSString *message = nil;
        UIColor *tintColor = nil;
        switch (self.deviceManager.state)
        {
            case MCTDeviceManagerStateConnected:
            {
                message = NSLocalizedString(@"Device Connected",
                                            @"Device Connected");
                tintColor = appearance.successStatusColor;
                break;
            }
            case MCTDeviceManagerStateError:
            {
                message = NSLocalizedString(@"Connection Error",
                                            @"Connection Error");
                tintColor = appearance.errorStatusColor;
                break;
            }
            case MCTDeviceManagerStateReady:
            case MCTDeviceManagerStateUnknown: // Pass through to default
            default:
            {
                message = NSLocalizedString(@"Connecting To Device",
                                            @"Connecting To Device");
                tintColor = appearance.successStatusColor;
                break;
            }
        }
        [[[self footerView] textLabel] setText:message];
        [[[self footerView] imageView] setTintColor:tintColor];
    }
}

#pragma mark - Field validation

- (BOOL)validateServerAddressString:(NSString *)serverAddress
{
    NSString *regex = @"(http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    BOOL isValid = [predicate evaluateWithObject:serverAddress];
    [self setValidServerAddress:isValid];
    return isValid;
}

- (BOOL)validateDeviceUUIDString:(NSString *)UUIDString
{
    BOOL isValid = (UUIDString.length >= 3);
    [self setValidDeviceUUID:isValid];
    return isValid;
}

#pragma mark - Update text field status

- (void)updateTextFieldStatus:(UITextField *)textField
{
    MCTSession *session = [MCTSession sharedSession];
    if ([textField isEqual:self.serverAddressCell.textField])
    {
        if ([self validateServerAddressString:textField.text])
        {
            NSURLComponents *components = [NSURLComponents componentsWithString:textField.text];
            [session setServerURL:components.URL];
        }
        else
        {
            [session setServerURL:nil];
            [textField setTextColor:[[MCTAppearance appearance] buttonTextColor]];
        }
    }
    else
    {
        if([self validateDeviceUUIDString:textField.text])
        {
            [session setDeviceUUID:textField.text];
        }
        else
        {
            [session setDeviceUUID:nil];
            [textField setTextColor:[[MCTAppearance appearance] buttonTextColor]];
        }
    }
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    MCTSession *session = [MCTSession sharedSession];
    if ([textField isEqual:self.serverAddressCell.textField])
    {
        [session setServerURL:nil];
    }
    else
    {
        [session setDeviceUUID:nil];
    }
    [[self deviceManager] cancelDeviceConnection];
    [self updateStatusView];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *newString = [[textField text] stringByReplacingCharactersInRange:range withString:string];
    if ([textField isEqual:self.serverAddressCell.textField])
    {
        [self validateServerAddressString:newString];
    }
    else
    {
        [self validateDeviceUUIDString:newString];
    }
    [textField setTextColor:[[MCTAppearance appearance] primaryTextColor]];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    [self updateTextFieldStatus:textField];
    if (self.serverAddressCell.textField.isEditing == NO &&
        self.deviceUUIDCell.textField.isEditing == NO)
    {
        [self connectDeviceIfReady];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self updateTextFieldStatus:textField];
    if ([textField isEqual:self.serverAddressCell.textField] &&
        self.isValidServerAddress)
    {
        [[[self deviceUUIDCell] textField] becomeFirstResponder];
        return YES;
    }
    [textField resignFirstResponder];
    return self.isValidDeviceUUID;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    CGPoint point = [gestureRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [[self tableView] indexPathForRowAtPoint:point];
    if (indexPath == nil)
    {
        if (point.y >= (CGRectGetHeight(self.tableView.bounds) - 180.0) ||
            self.serverAddressCell.textField.isFirstResponder ||
            self.deviceUUIDCell.textField.isFirstResponder)
        {
            return YES;
        }
    }
    return NO;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return MCTSettingsTableViewSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    switch ((MCTSettingsTableViewSection)indexPath.section)
    {
        case MCTSettingsTableViewSectionServerAddress:
        {
            MCTSession *session = [MCTSession sharedSession];
            if (session.serverURL)
            {
                [[self.serverAddressCell textField] setText:session.serverURL.absoluteString];
                [self setValidServerAddress:YES];
            }
            cell = self.serverAddressCell;
            break;
        }
        case MCTSettingsTableViewSectionDeviceUUID:
        {
            MCTSession *session = [MCTSession sharedSession];
            if (session.deviceUUID)
            {
                [[self.deviceUUIDCell textField] setText:session.deviceUUID];
            }
            cell = self.deviceUUIDCell;
            break;
        }
        case MCTSettingsTableViewSectionServerTrust:
        {
            MCTSession *session = [MCTSession sharedSession];
            [[[self serverTrustCell] settingsSwitch] setOn:session.shouldIgnoreServerTrustErrors];
            cell = self.serverTrustCell;
            break;
        }
        default:
        {
            cell = [tableView dequeueReusableCellWithIdentifier:[UITableViewCell mct_reuseIdentifier]
                                                   forIndexPath:indexPath];
        }
            break;
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *title = nil;
    switch (section)
    {
        case MCTSettingsTableViewSectionServerAddress:
        {
            title = [@"Server Address" uppercaseString];
            break;
        }
        case MCTSettingsTableViewSectionDeviceUUID:
        {
            title = [@"Device UUID" uppercaseString];
            break;
        }
        case MCTSettingsTableViewSectionServerTrust:
        {
            title = [@"Server Trust" uppercaseString];
            break;
        }
        default:
            break;
    }
    return title;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 59.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 36.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 1.0;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    MCTAppearance *appearance = [MCTAppearance appearance];
    UITableViewHeaderFooterView *headerView = (UITableViewHeaderFooterView *)view;
    [[headerView textLabel] setFont:appearance.headerFont];
    [[headerView textLabel] setTextColor:appearance.primaryTextColor];
    [[headerView contentView] setBackgroundColor:appearance.secondaryBackgroundViewColor];
}

#pragma mark - MCTDeviceManagerDelegate

- (void)deviceManagerDidUpdateState:(MCTDeviceManager *)manager
{
    [self updateStatusView];
}

- (void)deviceManager:(MCTDeviceManager *)central didConnectDevice:(MCTDevice *)device
{
    [self updateStatusView];
}

- (void)deviceManager:(MCTDeviceManager *)central didFailToConnectDevice:(NSError *)error
{
    [self updateStatusView];
}

@end
