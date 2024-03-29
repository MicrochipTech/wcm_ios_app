//
//  MCTDeviceViewController.m
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

#import "MCTDeviceViewController.h"
#import "MCTDeviceButtonLEDCell.h"
#import "MCTDevicePotentiometerCell.h"
#import "MCTDeviceHeaderView.h"
#import "MCTStatusFooterView.h"
#import "MCTDrawerViewController.h"
#import "MCTDeviceManager.h"
#import "MCTDevice.h"
#import "MCTCharacteristic.h"
#import "MCTSession.h"
#import "MCTAppearance.h"

static NSString *MCTDevicePotentiometerHeaderView = @"MCTDevicePotentiometerHeaderView";
static NSString *MCTDeviceButtonLEDHeaderView = @"MCTDeviceButtonLEDHeaderView";

typedef NS_ENUM(NSUInteger, MCTDeviceTableViewSection)
{
    MCTDeviceTableViewSectionButtonsLEDs,
    MCTDeviceTableViewSectionPotentiometer,
    MCTDeviceTableViewSectionCount,
};

@interface MCTDeviceViewController () <MCTDeviceManagerDelegate, MCTDeviceDelegate>

@property (nonatomic, strong) NSMutableDictionary *staticCells;
@property (nonatomic, strong) NSMutableDictionary *staticSwitches;
@property (nonatomic, strong) NSMutableDictionary *staticHeaders;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *consoleButtonItem;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *closeButtonItem;
@property (nonatomic, strong) MCTStatusFooterView *footerView;
@property (nonatomic, strong) MCTDeviceManager *deviceManager;
@property (nonatomic, weak) UISwitch *updatingSwitch;
@property (nonatomic, readwrite) BOOL didSuspendConnectionOnEnterBackground;

@end

@implementation MCTDeviceViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)awakeFromNib
{
    [self setupDeviceViewController];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupTitleView];
    [self setupTableView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self connectDeviceIfReady];
    [self updateStatusView];    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[self deviceManager] cancelDeviceConnection];
}

- (void)setupDeviceViewController
{
    [self setupApplicationNotificationObservers];
    [self setDeviceManager:[MCTDeviceManager new]];
    [[self deviceManager] setDelegate:self];
    [[self deviceManager] setShouldPollDeviceForUpdates:YES];
    [self setStaticCells:[NSMutableDictionary new]];
    [self setStaticSwitches:[NSMutableDictionary new]];
    [self setStaticHeaders:[NSMutableDictionary new]];
    [self setupBarButtonItems];
    [self setupNotifications];
}

- (void)setupApplicationNotificationObservers
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(applicationDidEnterBackgroundNotification:)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(applicationDidBecomeActiveNotification:)
                   name:UIApplicationDidBecomeActiveNotification
                 object:nil];
}

- (void)setupBarButtonItems
{
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@""
                                                             style:UIBarButtonItemStyleBordered
                                                            target:nil
                                                            action:nil];
    [[self navigationItem] setBackBarButtonItem:item];
    
    UIBarButtonItem *closeItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", @"Close")
                                                                  style:UIBarButtonItemStyleBordered
                                                                 target:self
                                                                 action:@selector(closeBarButtonPressed:)];
    [self setCloseButtonItem:closeItem];
}

- (void)setupNotifications
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(drawerViewWillOpenNotification:)
                   name:MCTDrawerViewControllerWillOpenNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(drawerViewWillCloseNotification:)
                   name:MCTDrawerViewControllerWillCloseNotification
                 object:nil];
}

- (void)setupTitleView
{
    UIImage *logoImage = [UIImage imageNamed:@"img_logo_navbar"];
    UIImageView *titleView = [[UIImageView alloc] initWithImage:logoImage];
    [[self navigationItem] setTitleView:titleView];
}

- (void)setupTableView
{
    MCTAppearance *appearance = [MCTAppearance appearance];
    [[self tableView] setBackgroundColor:appearance.secondaryBackgroundViewColor];
    
    [[self tableView] registerClass:[UITableViewCell class]
             forCellReuseIdentifier:NSStringFromClass(UITableViewCell.class)];
    [[self tableView] registerNib:[MCTDeviceButtonLEDCell mct_nib]
           forCellReuseIdentifier:[MCTDeviceButtonLEDCell mct_reuseIdentifier]];
    [[self tableView] registerNib:[MCTDevicePotentiometerCell mct_nib]
           forCellReuseIdentifier:[MCTDevicePotentiometerCell mct_reuseIdentifier]];
    
    MCTStatusFooterView *footerView = [MCTStatusFooterView mct_instantiateFromNib];
    [self setFooterView:footerView];
    [[self tableView] setTableFooterView:footerView];
    
    UIRefreshControl *refreshControl = [UIRefreshControl new];
    [refreshControl addTarget:self
                       action:@selector(refreshControlValueChanged:)
             forControlEvents:UIControlEventValueChanged];
    [self setRefreshControl:refreshControl];
}

#pragma mark - Device connect

/**
 *  Checks the ready state of the shared
 *  session and connects to the device
 *  matching the UUID provided.
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
        
        // Start the connection
        MCTDevice *device = [[MCTDevice alloc] initWithUUID:session.deviceUUID];
        [device setDelegate:self];
        [[self deviceManager] connectDevice:device];
    }
    else
    {
        [[self tableView] reloadRowsAtIndexPaths:self.tableView.indexPathsForVisibleRows
                                withRowAnimation:UITableViewRowAnimationNone];
    }
}

#pragma mark - Pull to reconnect

- (void)refreshControlValueChanged:(UIRefreshControl *)refreshControl
{
    MCTSession *session = [MCTSession sharedSession];
    if (session.isFullyConfigured == NO)
    {
        [refreshControl endRefreshing];
    }
    else
    {
        [self connectDeviceIfReady];
    }
}

#pragma mark - Device status updates

- (void)updateStatusView
{
    MCTAppearance *appearance = [MCTAppearance appearance];
    MCTSession *session = [MCTSession sharedSession];
    if (session.isFullyConfigured == NO)
    {
        [[self refreshControl] endRefreshing];
        [[[self footerView] imageView] setTintColor:appearance.errorStatusColor];
        [[[self footerView] textLabel] setText:NSLocalizedString(@"Device Not Configured",
                                                                 @"Device Not Configured")];
    }
    else
    {
        NSString *message = nil;
        UIColor *tintColor = nil;
        switch (self.deviceManager.state)
        {
            case MCTDeviceManagerStateConnected:
            {
                [[self refreshControl] endRefreshing];
                message = NSLocalizedString(@"Device Connected",
                                            @"Device Connected");
                tintColor = appearance.successStatusColor;
                break;
            }
            case MCTDeviceManagerStateError:
            {
                [[self refreshControl] endRefreshing];
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
    [self updateRefreshControlTitle];
}

- (void)updateRefreshControlTitle
{
    NSString *title = NSLocalizedString(@"Device Not Configured", @"Device Not Configured");
    MCTSession *session = [MCTSession sharedSession];
    if (session.serverURL)
    {
        title = session.serverURL.absoluteString;
    }
    UIFont *font = [UIFont mct_lightFontOfSize:12.0];
    NSMutableAttributedString *attributedTitle = [[NSMutableAttributedString alloc] initWithString:title];
    [attributedTitle addAttribute:NSFontAttributeName
                            value:font
                            range:NSMakeRange(0, title.length)];
    [[self refreshControl] setAttributedTitle:attributedTitle];
}

#pragma mark - Control events

- (IBAction)consoleBarButtonPressed:(id)sender
{
    MCTDrawerViewController *controller = [MCTDrawerViewController sharedDrawerViewController];
    [controller springOpen];
}

- (IBAction)closeBarButtonPressed:(id)sender
{
    MCTDrawerViewController *controller = [MCTDrawerViewController sharedDrawerViewController];
    [controller springClose];
}

- (IBAction)ledSwitchValueChanged:(id)sender
{
    UISwitch *ledSwitch = (UISwitch *)sender;
    NSIndexPath *indexPath = [[[self staticSwitches] allKeysForObject:sender] firstObject];
    NSInteger index = (indexPath.item + 1);
    
    MCTDevice *device = self.deviceManager.connectedDevice;
    NSArray *leds = [device characteristicsWithPrefix:MCTCharacteristicLEDPrefix];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.identifier ENDSWITH[c] %@", @(index).stringValue];
    leds = [leds filteredArrayUsingPredicate:predicate];
    if (leds.count)
    {
        MCTCharacteristic *character = leds.firstObject;
        [device writeValue:@(ledSwitch.isOn) forCharacteristic:character];
    }
}

#pragma mark - Cell configuration

- (void)configureButtonLEDCell:(MCTDeviceButtonLEDCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    NSInteger index = indexPath.row + 1;
    NSString *buttonText = [NSString stringWithFormat:@"S%ld", (long)index];
    NSString *ledText = [NSString stringWithFormat:@"D%ld", (long)index];
    [[cell buttonLabel] setText:buttonText];
    [[cell ledLabel] setText:ledText];
    if (index == 4)
    {
        [cell setSeparatorInset:UIEdgeInsetsZero];
    }
    
    // Apply current button status
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.identifier ENDSWITH[c] %@", @(index).stringValue];
    MCTDevice *device = self.deviceManager.connectedDevice;
    NSArray *buttons = [device characteristicsWithPrefix:MCTCharacteristicButtonPrefix];
    buttons = [buttons filteredArrayUsingPredicate:predicate];
    if (buttons.count)
    {
        MCTCharacteristic *character = buttons.firstObject;
        [cell setButtonStatusOn:character.value.boolValue];
    }
    else
    {
        [cell setButtonStatusOn:NO];
    }
    
    // Apply current led status
    if ([[self updatingSwitch] isEqual:cell.ledSwitch])
    {
        [self setUpdatingSwitch:nil];
    }
    else
    {
        NSArray *leds = [device characteristicsWithPrefix:MCTCharacteristicLEDPrefix];
        leds = [leds filteredArrayUsingPredicate:predicate];
        if (leds.count)
        {
            MCTCharacteristic *character = leds.firstObject;
            [[cell ledSwitch] setOn:character.value.boolValue animated:YES];
        }
        else
        {
            [[cell ledSwitch] setOn:NO];
        }
    }
}

- (void)configurePotentiometerCell:(MCTDevicePotentiometerCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    MCTDevice *device = self.deviceManager.connectedDevice;
    NSArray *characters = [device characteristicsWithPrefix:MCTCharacteristicPotentiometerPrefix];
    if (characters.count)
    {
        MCTCharacteristic *character = characters.firstObject;
        [[cell meterLabel] setText:character.value.stringValue];
        
        CGFloat percentage = (character.value.floatValue / MCTCharacteristicMaximumPotentiometerValue);
        [cell setMeterPercentage:percentage animated:YES];
    }
    else
    {
        [[cell meterLabel] setText:@"0"];
        [cell setMeterPercentage:0.0 animated:YES];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return MCTDeviceTableViewSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger count = 0;
    switch ((MCTDeviceTableViewSection)section)
    {
        case MCTDeviceTableViewSectionButtonsLEDs:
        {
            count = 4;
            break;
        }
        case MCTDeviceTableViewSectionPotentiometer:
        {
            count = 1;
            break;
        }
        default:
            break;
    }
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    switch ((MCTDeviceTableViewSection)indexPath.section)
    {
        case MCTDeviceTableViewSectionButtonsLEDs:
        {
            MCTDeviceButtonLEDCell *deviceCell = self.staticCells[indexPath];
            if (!deviceCell)
            {
                deviceCell = [tableView dequeueReusableCellWithIdentifier:[MCTDeviceButtonLEDCell mct_reuseIdentifier]
                                                       forIndexPath:indexPath];
                self.staticCells[indexPath] = deviceCell;
                self.staticSwitches[indexPath] = deviceCell.ledSwitch;
                [[deviceCell ledSwitch] addTarget:self
                                           action:@selector(ledSwitchValueChanged:)
                                 forControlEvents:UIControlEventValueChanged];
            }
            [self configureButtonLEDCell:deviceCell atIndexPath:indexPath];
            cell = deviceCell;
            break;
        }
        case MCTDeviceTableViewSectionPotentiometer:
        {
            MCTDevicePotentiometerCell *deviceCell = self.staticCells[indexPath];
            if (!deviceCell)
            {
                deviceCell = [tableView dequeueReusableCellWithIdentifier:[MCTDevicePotentiometerCell mct_reuseIdentifier]
                                                       forIndexPath:indexPath];
                self.staticCells[indexPath] = deviceCell;
            }
            [self configurePotentiometerCell:deviceCell atIndexPath:indexPath];
            cell = deviceCell;
            break;
        }
        default:
        {
            cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(UITableViewCell.class)
                                                   forIndexPath:indexPath];
        }
            break;
    }
    return cell;
}

#pragma mark - UITableViewDelegate

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *view = nil;
    switch ((MCTDeviceTableViewSection)section)
    {
        case MCTDeviceTableViewSectionButtonsLEDs:
        {
            view = self.staticHeaders[MCTDeviceButtonLEDHeaderView];
            if (!view)
            {
                view = [MCTDeviceHeaderView mct_instantiateWithNibNamed:MCTDeviceButtonLEDHeaderView];
                self.staticHeaders[MCTDeviceButtonLEDHeaderView] = view;
            }
            break;
        }
        case MCTDeviceTableViewSectionPotentiometer:
        {
            view = self.staticHeaders[MCTDevicePotentiometerHeaderView];
            if (!view)
            {
                view = [MCTDeviceHeaderView mct_instantiateWithNibNamed:MCTDevicePotentiometerHeaderView];
                self.staticHeaders[MCTDevicePotentiometerHeaderView] = view;
            }
            break;
        }
        default:
            break;
    }
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 36.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 1.0;
}

#pragma mark - Drawer view notifications

- (void)drawerViewWillOpenNotification:(NSNotification *)notification
{
    [[self navigationItem] setLeftBarButtonItem:self.closeButtonItem
                                       animated:YES];
    
    for (MCTDeviceCell *cell in self.staticCells.allValues)
    {
        [cell setDrawerOpenState:YES];
    }
    
    MCTDeviceHeaderView *buttonLED = self.staticHeaders[MCTDeviceButtonLEDHeaderView];
    NSString *buttonText = NSLocalizedString(@"S", @"Button short section header label");
    [[buttonLED textLabel] setText:buttonText.uppercaseString];
    NSString *ledText = NSLocalizedString(@"D", @"LED short section header label");
    [[buttonLED detailTextLabel] setText:ledText.uppercaseString];
    [buttonLED setDrawerOpenState:YES];
    
    MCTDeviceHeaderView *potentiometer = self.staticHeaders[MCTDevicePotentiometerHeaderView];
    NSString *potText = NSLocalizedString(@"Pot", @"Potentiometer short section header label");
    [[potentiometer textLabel] setText:potText.uppercaseString];
    [buttonLED setDrawerOpenState:YES];
}

- (void)drawerViewWillCloseNotification:(NSNotification *)notification
{
    [[self navigationItem] setLeftBarButtonItem:self.consoleButtonItem
                                       animated:YES];
    
    for (MCTDeviceCell *cell in self.staticCells.allValues)
    {
        [cell setDrawerOpenState:NO];
    }
    
    MCTDeviceHeaderView *buttonLED = self.staticHeaders[MCTDeviceButtonLEDHeaderView];
    NSString *buttonText = NSLocalizedString(@"Buttons", @"Button section header label");
    [[buttonLED textLabel] setText:buttonText.uppercaseString];
    NSString *ledText = NSLocalizedString(@"LEDs", @"LED section header label");
    [[buttonLED detailTextLabel] setText:ledText.uppercaseString];
    [buttonLED setDrawerOpenState:NO];
    
    MCTDeviceHeaderView *potentiometer = self.staticHeaders[MCTDevicePotentiometerHeaderView];
    NSString *potText = NSLocalizedString(@"Potentiometer", @"Potentiometer section header label");
    [[potentiometer textLabel] setText:potText.uppercaseString];
    [buttonLED setDrawerOpenState:NO];
}

#pragma mark - MCTDeviceManagerDelegate

- (void)deviceManagerDidUpdateState:(MCTDeviceManager *)manager
{
    // Update status footer
    [self updateStatusView];
}

- (void)deviceManager:(MCTDeviceManager *)central didFailToConnectDevice:(NSError *)error
{
}

#pragma mark - MCTDeviceDelegate

- (void)deviceDidUpdateCharacteristicValues:(MCTDevice *)device
{
    [self updateStatusView];
    [[self tableView] reloadRowsAtIndexPaths:self.tableView.indexPathsForVisibleRows
                            withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - UIApplication notifications

- (void)applicationDidEnterBackgroundNotification:(NSNotification *)notification
{
    [[self deviceManager] cancelDeviceConnection];
    [self setDidSuspendConnectionOnEnterBackground:YES];
}

- (void)applicationDidBecomeActiveNotification:(NSNotification *)notification
{
    if (self.didSuspendConnectionOnEnterBackground)
    {
        [self setDidSuspendConnectionOnEnterBackground:NO];
        [self connectDeviceIfReady];
    }
}

@end
