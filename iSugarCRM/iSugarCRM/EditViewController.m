//
//  EditViewController.m
//  iSugarCRM
//
//  Created by dayanand on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//
#import "DataObjectField.h"
#import "EditViewController.h"
#import "DataObjectMetadata.h"
#import "DataObject.h"
#import "SyncHandler.h"
#import "UITableViewCellItem.h"
#import "EditViewRowItem.h"
#import "AppDelegate.h"
#import "EditViewSectionItem.h"
#import "SyncHandler.h"
#import "DBSession.h"
#import "DBHelper.h"

#define kSideMargin 5.0
#define kLabelWidth 150.0
#define KCellHeight 50.0
#define kHeightlMargin 30.0
#define kPrevSegementItemIndex 0
#define kNextSegementItemIndex 1
#define kHourPickerTag      1002
#define kMinPickerTag       1003
#define kUserPickerTag       1004
#define kAccountPickerTag       1005

@interface EditViewController ()
{
    UIPopoverController* popoverController;
}
@property(strong) UITableView *_tableView;
@property(strong) NSMutableDictionary *dataSource;
@property(strong) NSArray *detailedData;


@property(strong) NSMutableArray *editableDataObjectFields;
@property(nonatomic, strong) NSArray* userList;
@property(nonatomic, strong) NSArray* accounts;
@property(nonatomic,strong) UIToolbar *toolBar;
@property(nonatomic,strong) UIDatePicker *datePicker;
@property(nonatomic, strong) UIPickerView* userPicker;
@property(strong) UIActionSheet *actionSheet;

-(void)registerForKeyboardNotifications;
-(void)unRegisterForKeyboardNotifications;
-(void)dismissPicker:(UIView*) picker;
-(CGRect)toolBarFrame;
-(CGRect)pickerViewFrame;
-(void)arrangeViews:(UIInterfaceOrientation)orientation;
-(void)scrollCell:(UITableViewCell*)cell;
-(NSInteger)effectiveRowIndexWithIndexPath:(NSIndexPath *)indexpath;
-(BOOL)hasNext:(NSIndexPath *)indexPath;
-(BOOL)hasPrevious:(NSIndexPath *)indexPath;
-(NSInteger)totalRowsCount;
-(BOOL)isValidRecord;
-(void) showTimePicker:(NSString*) value;
-(void) showDatePicker:(NSString*) dateText;
-(void) showUserPicker:(NSString*) userName;
-(void) showAccountPicker:(NSString*) accountName;
@end

@implementation EditViewController
@synthesize _tableView;
@synthesize dataSource;
@synthesize metadata;
@synthesize detailedData;
@synthesize editableDataObjectFields;
@synthesize userList;
@synthesize accounts;
@synthesize toolBar;
@synthesize datePicker;
@synthesize userPicker;
@synthesize actionSheet;
//@synthesize detailedData;



#pragma mark - View lifecycle

+(EditViewController*)editViewControllerWithMetadata:(DataObjectMetadata*)metadata{

    EditViewController *editViewController = [[EditViewController alloc] init];
    editViewController.metadata = metadata;
    return editViewController;

}

+(EditViewController*)editViewControllerWithMetadata:(DataObjectMetadata*)metadata andDetailedData:(NSMutableArray *)detailedData{
    
    EditViewController *editViewController = [[EditViewController alloc] init];
    editViewController.metadata = metadata;
    editViewController.detailedData = detailedData;
    return editViewController;
}
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
    [super loadView];
    CGRect mainFrame = [[UIScreen mainScreen] applicationFrame];
    CGFloat width = mainFrame.size.width;
    CGFloat height = mainFrame.size.height;
    //_tableView = [[UITableView alloc]initWithFrame:[[UIScreen mainScreen]applicationFrame]];
    _tableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 0,width, height) style:UITableViewStyleGrouped];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];
    [self.view setAutoresizesSubviews:YES];
}

 // Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
    UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStyleDone target:self action:@selector(saveRecord)];
    self.navigationItem.rightBarButtonItem = barButtonItem;
    UIBarButtonItem *discardButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Discard" style:UIBarButtonItemStylePlain target:self action:@selector(discard)];
    self.navigationItem.leftBarButtonItem = discardButtonItem;
    [self performSelectorOnMainThread:@selector(getEditableDataObjectFieldArray) withObject:nil waitUntilDone:NO];
    
    for (UIView * subview in self.datePicker.subviews) {
        subview.frame = datePicker.bounds;
    }
    
}
-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // register for keyboard notifications
    [self registerForKeyboardNotifications];
    [self arrangeViews:[UIApplication sharedApplication].statusBarOrientation];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    // unregister for keyboard notifications while not visible.
    [self unRegisterForKeyboardNotifications];
}

-(void)getEditableDataObjectFieldArray{
    NSArray *dataObjectFields = [metadata.fields allObjects];
    editableDataObjectFields = [[NSMutableArray alloc] init];
    NSMutableArray *mandatoryFields = [[NSMutableArray alloc] init];
    NSMutableArray *optionalFields = [[NSMutableArray alloc] init];
    EditViewSectionItem *mandatorySection = [[EditViewSectionItem alloc]init];
    EditViewSectionItem *optionalSection = [[EditViewSectionItem alloc]init];
    dataSource = [[NSMutableDictionary alloc] init];
    DataObject *dataObject = (DataObject *)[detailedData objectAtIndex:0];
    for (DataObjectField *dof in dataObjectFields) {
        if (dof.editable == TRUE){
            if(dataObject){
                [dataSource setObject:[dataObject objectForFieldName:dof.name] forKey:dof.name];
            }
            if (dof.mandatory == TRUE) {
                if ([dataObject objectForFieldName:dof.name] == nil || [[dataObject objectForFieldName:dof.name] length] == 0) {
                    self.navigationItem.rightBarButtonItem.enabled = NO;
                }
                [mandatoryFields addObject:dof];
            }else{
                [optionalFields addObject:dof];
            }
        }
    }
    mandatorySection.sectionTitle = @"Required";
    mandatorySection.rowItems = mandatoryFields;
    optionalSection.sectionTitle = @"Optional";
    optionalSection.rowItems = optionalFields;
    [editableDataObjectFields addObject:mandatorySection];
    [editableDataObjectFields addObject:optionalSection];
    [_tableView reloadData];
}

- (void)viewDidUnload
{
    dataSource = nil;
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}
-(void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    //When application goes to background in Landscapemode and user relaunches in potraitmode(viceversa also) should clear if there is any contentInset set to the tableview
    [super willAnimateRotationToInterfaceOrientation: toInterfaceOrientation
                                            duration: duration];
    _tableView.contentInset =  UIEdgeInsetsZero;
    [self arrangeViews: toInterfaceOrientation];
    if(popoverController)
    {
        [popoverController dismissPopoverAnimated:NO];
        popoverController = nil;
    }
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    UITableViewCell *cell = [_tableView cellForRowAtIndexPath:selectedIndexPath];
    if ([cell.reuseIdentifier isEqualToString:@"date"]) {
        toolBar.frame = CGRectMake(0,_tableView.frame.size.height-datePicker.frame.size.height-35,datePicker.frame.size.width,35);
    }
}

- (void) arrangeViews: (UIInterfaceOrientation)orientation {
    if (UIInterfaceOrientationIsPortrait(orientation)) {
        datePicker.frame = CGRectMake(0, 200, 320, 216);
    }
    else {
        datePicker.frame = CGRectMake(0, 106, 480, 162);
    }
}

-(void)saveRecord{
    
    [self.view endEditing:YES];
    SugarCRMMetadataStore *sharedInstance = [SugarCRMMetadataStore sharedInstance];
    DBSession * dbSession = [DBSession sessionWithMetadata:[sharedInstance dbMetadataForModule:self.metadata.objectClassIdentifier]];
    
    DataObject *dataObject = (DataObject *)[detailedData objectAtIndex:0];
    if(dataObject == nil)
    {
        
        dataObject = [[DataObject alloc] initWithMetadata:[sharedInstance objectMetadataForKey:self.metadata.objectClassIdentifier]];
    }
    else
    {
        if(![dbSession resetDirtyFlagForId:dataObject]){
            return; // add alert for error.
        }
    }
    for (NSString *key in [dataSource allKeys]) {
        [dataObject setObject:[dataSource objectForKey:key] forFieldName:key];
    }
    SyncHandler * syncHandler = [SyncHandler sharedInstance];
    syncHandler.delegate = self;
    [syncHandler uploadData:[NSArray arrayWithObject:[dataObject nameValueArray]] forModule:self.metadata.objectClassIdentifier parent:self];
    
    AppDelegate *sharedAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [sharedAppDelegate showWaitingAlertWithMessage:@"Please wait syncing"];
}

-(BOOL)isValidRecord
{
    EditViewSectionItem *evSectionItem = [editableDataObjectFields objectAtIndex:0];//getting required fields
    NSArray *dataObjectFields  = evSectionItem.rowItems;
    BOOL saveRecord = TRUE;
    
    for (int i=0; i<[dataObjectFields count]; i++) {
        DataObjectField *dof = [dataObjectFields objectAtIndex:i];
        NSString *value = [dataSource objectForKey:dof.name];
        if (value == nil || [value length] == 0) {
            saveRecord = FALSE;
            break;
        }
    }
    return saveRecord;
}

-(void) discard
{
    dataSource = nil;
    [self.navigationController dismissModalViewControllerAnimated:YES];
}

#pragma mark - TableView DataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [editableDataObjectFields count];

}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [[[editableDataObjectFields objectAtIndex:section] rowItems] count];
}

- (NSString *)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *sectionTitle = [[editableDataObjectFields objectAtIndex:section] sectionTitle];
    return sectionTitle;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    EditViewSectionItem *evSectionItem = [editableDataObjectFields objectAtIndex:indexPath.section];
    DataObjectField *dof  = [evSectionItem.rowItems objectAtIndex:indexPath.row];
    EditViewRowItem *evRowItem = [[EditViewRowItem alloc] init];
    UITableViewCell *cell;
    evRowItem.label = dof.label;
    evRowItem.action = dof.action;
    evRowItem.delegate = self;
    if(detailedData != nil){
        NSLog(@"value of dataobject %@ and field %@",[dataSource objectForKey:dof.name],dof.name);
        evRowItem.value = [dataSource objectForKey:dof.name];
        cell = [evRowItem reusableCellForTableView:tableView];
        if([cell.reuseIdentifier isEqualToString:@"date"])
        {
            UILabel *valueField = (UILabel*)[cell.contentView viewWithTag:1001];
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateStyle:NSDateFormatterShortStyle];
            [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
            if([dateFormatter dateFromString:valueField.text] == nil)
                [dataSource setObject:@"" forKey:dof.name];
        }
    }
    else{
        if ([dataSource objectForKey:dof.name]) {
            evRowItem.value = [dataSource objectForKey:dof.name];
        }
        else
        {
            evRowItem.value = @"";
        }
        cell = [evRowItem reusableCellForTableView:tableView];
        if([cell.reuseIdentifier isEqualToString:@"date"])
        {
            UILabel *valueField = (UILabel*)[cell.contentView viewWithTag:1001];
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateStyle:NSDateFormatterShortStyle];
            [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
            if([dateFormatter dateFromString:valueField.text] == nil)
                [dataSource setObject:@"" forKey:dof.name];
        }
    }
    
    
    return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    EditViewSectionItem *evSectionItem = [editableDataObjectFields objectAtIndex:indexPath.section];
    DataObjectField *dof  = [evSectionItem.rowItems objectAtIndex:indexPath.row];
    EditViewRowItem *evRowItem = [[EditViewRowItem alloc] init];
    evRowItem.label = dof.label;
    evRowItem.action = dof.action;
    if(detailedData != nil){
        evRowItem.value = [(DataObject *)[detailedData objectAtIndex:0] objectForFieldName:dof.name];
    }
    else{
        evRowItem.value = @"";
    }
    return [evRowItem heightForCell:(UITableView*)tableView];
}

#pragma mark - TableView delegate methods
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    selectedIndexPath = indexPath;
    UITableViewCell *cell = [_tableView cellForRowAtIndexPath:indexPath];
    if([cell.reuseIdentifier isEqualToString:@"date"])
    {
        UILabel *valueField = (UILabel*)[cell.contentView viewWithTag:1001];
        [self showDatePicker:valueField.text];
        [self scrollCell:cell];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    else if([cell.reuseIdentifier isEqualToString:@"time"])
    {
        [self.view endEditing:YES]; // resign firstResponder if you have any text fields so the keyboard doesn't get in the way
        UILabel *valueField = (UILabel*)[cell.contentView viewWithTag:1001];
        [self showTimePicker:valueField.text];
        [self scrollCell:cell];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    else if([cell.reuseIdentifier isEqualToString:@"assigned_user_name"])
    {
        [self.view endEditing:YES]; 
        UILabel *valueField = (UILabel*)[cell.contentView viewWithTag:1001];
        [self showUserPicker:valueField.text];
        [self scrollCell:cell];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    else if([cell.reuseIdentifier isEqualToString:@"account_name"])
    {
        [self.view endEditing:YES]; 
        UILabel *valueField = (UILabel*)[cell.contentView viewWithTag:1001];
        [self showAccountPicker:valueField.text];
        [self scrollCell:cell];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    else{
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}
#pragma mark - TextField delegate methods
- (void) textFieldDidBeginEditing:(UITextField *)textField {
    [self dismissPicker:self.datePicker];
    UITableViewCell *cell = (UITableViewCell *)textField.superview.superview;
    [self scrollCell:cell];
}
- (void) textFieldDidEndEditing:(UITextField *)textField {
    EditViewSectionItem *evSectionItem = [editableDataObjectFields objectAtIndex:selectedIndexPath.section];
    DataObjectField *dof  = [evSectionItem.rowItems objectAtIndex:selectedIndexPath.row];
    [dataSource setObject:textField.text forKey:dof.name];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
    _tableView.contentInset =  UIEdgeInsetsZero;
    UITableViewCell *cell = (UITableViewCell *)textField.superview.superview;
    [_tableView scrollToRowAtIndexPath:[_tableView indexPathForCell:cell] atScrollPosition:UITableViewScrollPositionBottom animated:YES ];
    return YES;
}

#pragma mark SyncHandler Delegate

-(void)syncHandler:(SyncHandler*)syncHandler failedWithError:(NSError*)error{   
     dispatch_async(dispatch_get_main_queue(), ^(void) {
         AppDelegate *sharedAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
         [sharedAppDelegate dismissWaitingAlert];
         [self performSelectorOnMainThread:@selector(showSyncAlert:) withObject:error waitUntilDone:NO];
     });
}

-(void)syncComplete:(SyncHandler*)syncHandler{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        AppDelegate *sharedAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        [sharedAppDelegate dismissWaitingAlert];
        [self.navigationController dismissModalViewControllerAnimated:YES];
        [[NSNotificationCenter defaultCenter]postNotificationName:@"ReloadRecords" object:nil];
        [self performSelectorOnMainThread:@selector(showSyncAlert:) withObject:nil waitUntilDone:NO];
    });
}

-(IBAction)showSyncAlert:(id)sender
{
    NSError* error = (NSError*) sender;
    if(error)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
        [alertView show];
    }
    else
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Sync Completed" message:@"Sync Completed" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
        [alertView show];
    }
}

//register for keyboard notifications.
- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
}

//unregister for keyboard notifications.
- (void)unRegisterForKeyboardNotifications{
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:UIKeyboardWillShowNotification 
                                                  object:nil]; 
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:UIKeyboardWillHideNotification 
                                                  object:nil];
}

-(void)keyboardWillShow:(NSNotification *)notification
{
    kbBeginSize = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    if(!IS_IPAD)
    {
        self.toolBar.alpha = 1.0;
        toolBar.frame=[self toolBarFrame];
        [self.view addSubview:toolBar];
    }
}
-(void)keyboardWillBeHidden:(NSNotification *)notification
{
    if(!IS_IPAD)
    {
        toolBar.alpha = 0.0;
        toolBar.frame = CGRectMake(0,500,self.toolBar.frame.size.width,self.toolBar.frame.size.height);
    }
    _tableView.contentInset = UIEdgeInsetsZero;
}

- (void)pickerView:(UIPickerView *)listPickerView didSelectRow: (NSInteger)row inComponent:(NSInteger)component {
    // Handle the selection
    UITableViewCell *cell = [_tableView cellForRowAtIndexPath:selectedIndexPath];
    UILabel *dateValue = (UILabel *)[cell.contentView viewWithTag:1001];
    NSString* selectedValue = [self pickerView:listPickerView titleForRow:row forComponent:component];
    dateValue.text = selectedValue;
    EditViewSectionItem *evSectionItem = [editableDataObjectFields objectAtIndex:selectedIndexPath.section];
    DataObjectField *dof  = [evSectionItem.rowItems objectAtIndex:selectedIndexPath.row];
   [(DataObject *)[detailedData objectAtIndex:0] setObject:selectedValue forFieldName:dof.name];
    [dataSource setObject:selectedValue forKey:dof.name];
    self.navigationItem.rightBarButtonItem.enabled = [self isValidRecord];
}

- (NSInteger)pickerView:(UIPickerView *)timePickerView numberOfRowsInComponent:(NSInteger)component {
    NSInteger tag = timePickerView.tag;
    if(tag == kHourPickerTag)
    {
        return 24;   
    }
    else if(tag == kMinPickerTag)
    {
        return 60;
    }
    else if(tag == kUserPickerTag)
    {
        return [self.userList count];
    }
    else if( tag == kAccountPickerTag)
    {
        return [self.accounts count];
    }
    return 0;
}

// tell the picker how many components it will have
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)timePickerView {
    return 1;
}

// tell the picker the title for a given component
- (NSString *)pickerView:(UIPickerView *)timePickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    NSString *title;
    NSInteger tag = timePickerView.tag;
    if(tag == kHourPickerTag || tag == kMinPickerTag)
    {   
        title = [@"" stringByAppendingFormat:@"%d",row];
    }
    else if(tag == kUserPickerTag)
    {
        title = [[self.userList objectAtIndex:row] objectForKey:@"name"];
    }
    else if( tag == kAccountPickerTag)
    {
        DataObject* dataObject = [self.accounts objectAtIndex:row];
        title = [dataObject objectForFieldName:@"name"];
    }
    
    return title;
}

// tell the picker the width of each row for a given component
- (CGFloat)pickerView:(UIPickerView *)timePickerView widthForComponent:(NSInteger)component {
    int sectionWidth = 300;
    
    return sectionWidth;
}


-(CGRect)toolBarFrame
{
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    UITableViewCell *cell = [_tableView cellForRowAtIndexPath:selectedIndexPath];
    if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight)
    {
        if ([cell.reuseIdentifier isEqualToString:@"date"]){
            return CGRectMake(0, _tableView.frame.size.height-datePicker.frame.size.height-toolBar.frame.size.height,self.view.bounds.size.height,35);
        }else{
            return CGRectMake(0, _tableView.frame.size.height-kbBeginSize.width-toolBar.frame.size.height,self.view.bounds.size.width, toolBar.frame.size.height);
        }
    }
    else
    {
        if ([cell.reuseIdentifier isEqualToString:@"date"]) {
            return CGRectMake(0, _tableView.frame.size.height-datePicker.frame.size.height-toolBar.frame.size.height,self.view.bounds.size.width,toolBar.frame.size.height);
        }else{
            return CGRectMake(0,_tableView.frame.size.height-kbBeginSize.height-toolBar.frame.size.height,self.view.bounds.size.width,toolBar.frame.size.height);
        }
    }
}

-(CGRect)pickerViewFrame
{
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight)
    {
        return CGRectMake(0, 106, 480, 162);
    }
    else
    {   
        return CGRectMake(0, 200, 320, 216);
    }
}

-(NSArray*) userList
{
    
    if(!userList)
    {
        userList = [DBHelper loadUserList];
    }   
    return  userList;
}

-(NSArray*) accounts
{
    if(!accounts)
    {
        accounts = [DBHelper loadRecordsinModule:@"Accounts"];
    }    
    return accounts;
}

-(UIPickerView*) userPicker
{
    if(!userPicker)
    {
        userPicker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 44, 0, 216)];
        [userPicker setBackgroundColor:[UIColor clearColor]];
        userPicker.showsSelectionIndicator = YES;
        userPicker.delegate = self;
    }
    return userPicker;
}

-(UIDatePicker*) datePicker
{
    if(!datePicker){
        datePicker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, 44, 0, 0)];
        //pickerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [datePicker setDatePickerMode:UIDatePickerModeDateAndTime];
        [datePicker setBackgroundColor:[UIColor clearColor]];
        [datePicker addTarget:self action:@selector(dateChanged:) forControlEvents:UIControlEventValueChanged];
    }
    return datePicker;
}
-(UIToolbar *) toolBar
{
    if(toolBar == nil)
    {
        toolBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width,35)];
        toolBar.barStyle = UIBarStyleBlackTranslucent;
        toolBar.tintColor = [UIColor darkGrayColor];
        toolBar.barStyle = UIBarStyleBlackTranslucent;
        toolBar.tintColor = [UIColor darkGrayColor];
        UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissKeyboard:)];
        
        UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        
        UISegmentedControl *control = [[UISegmentedControl alloc] initWithItems:nil];
        control.momentary = YES;
        [control insertSegmentWithTitle:@"Previous" atIndex:kPrevSegementItemIndex animated:YES];
        [control insertSegmentWithTitle:@"Next" atIndex:kNextSegementItemIndex animated:YES];
        control.segmentedControlStyle = UISegmentedControlStyleBar;
        control.tintColor = [UIColor darkGrayColor];
        control.momentary = YES;
        [control addTarget:self action:@selector(nextPrevious:) forControlEvents:UIControlEventValueChanged];			
        UIBarButtonItem *controlItem = [[UIBarButtonItem alloc] initWithCustomView:control];
        
        NSArray *items = [[NSArray alloc] initWithObjects:controlItem, flex, barButtonItem, nil];
        [toolBar setItems:items];
    }
    return toolBar;
}

-(void)dismissKeyboard:(id)sender
{
    _tableView.contentInset = UIEdgeInsetsZero;
    toolBar.alpha = 0.0;
    [self.view endEditing:YES]; 
    UITableViewCell *cell = [_tableView cellForRowAtIndexPath:selectedIndexPath];
    if([cell.reuseIdentifier isEqualToString:@"date"]){
        [self dismissPicker:self.datePicker];
    }else if([cell.reuseIdentifier isEqualToString:@"time"] || [cell.reuseIdentifier isEqualToString:@"assigned_user_name"] || [cell.reuseIdentifier isEqualToString:@"account_name"]){
        [self dismissPicker:self.userPicker];
    }else{
        toolBar.frame = CGRectMake(0,500,self.toolBar.frame.size.width,self.toolBar.frame.size.height);
    }
}

-(void) dismissPicker:(UIView*) picker
{    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.5];
    self.datePicker.frame = CGRectMake(0, 500, picker.frame.size.width,picker.frame.size.height);
    [picker removeFromSuperview];
    [UIView commitAnimations];
}

- (void)dateChanged:(id)sender
{
	UITableViewCell *cell = [_tableView cellForRowAtIndexPath:selectedIndexPath];
    UILabel *dateValue = (UILabel *)[cell.contentView viewWithTag:1001];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MM/dd/yy"];
	dateValue.text = [dateFormatter stringFromDate:self.datePicker.date];
    EditViewSectionItem *evSectionItem = [editableDataObjectFields objectAtIndex:selectedIndexPath.section];
    DataObjectField *dof  = [evSectionItem.rowItems objectAtIndex:selectedIndexPath.row];
    NSDate *date = datePicker.date;
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
	[(DataObject *)[detailedData objectAtIndex:0] setObject:[dateFormatter stringFromDate:date] forFieldName:dof.name];
    [dataSource setObject:[dateFormatter stringFromDate:date] forKey:dof.name];
    self.navigationItem.rightBarButtonItem.enabled = [self isValidRecord];
}

-(void) showPicker:(UIView*) picker
{
    if(IS_IPAD)
    {
        UIViewController* popoverContent = [[UIViewController alloc] init];
        UIView* popoverView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 344)];
        popoverView.backgroundColor = [UIColor whiteColor];
        picker.frame = CGRectMake(0, 0, 320, 216);
        [popoverView addSubview:picker];
        popoverContent.view = popoverView;
        popoverContent.contentSizeForViewInPopover = CGSizeMake(320, 200);
        popoverController = [[UIPopoverController alloc] initWithContentViewController:popoverContent];
        [popoverController presentPopoverFromRect:[_tableView cellForRowAtIndexPath:selectedIndexPath].frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
    }
    else
    {    
        picker.frame = CGRectMake(0, 500, picker.frame.size.width,216);
        [picker setHidden:NO];
        [UIView beginAnimations:nil context:nil];
        picker.frame = [self pickerViewFrame];
        self.toolBar.frame = CGRectMake(0, _tableView.frame.size.height-picker.frame.size.height-self.toolBar.frame.size.height,self.view.bounds.size.width,35);
        self.toolBar.alpha = 1.0;
        [self.view addSubview:self.toolBar];
        [self.view addSubview:picker];
        [UIView commitAnimations];
    }
}

-(void) showTimePicker:(NSString*) value;
{
    [self._tableView scrollToRowAtIndexPath:selectedIndexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];     
    EditViewSectionItem *evSectionItem = [editableDataObjectFields objectAtIndex:selectedIndexPath.section];
    DataObjectField *dof  = [evSectionItem.rowItems objectAtIndex:selectedIndexPath.row];
    self.userPicker.tag = [dof.name isEqualToString:@"duration_hours"] ? kHourPickerTag:kMinPickerTag;
    [self.userPicker reloadAllComponents];
    [self.userPicker selectRow:[value integerValue] inComponent:0 animated:YES];
    [self showPicker:self.userPicker];
}

-(void) showUserPicker:(NSString *)userName
{
    [self._tableView scrollToRowAtIndexPath:selectedIndexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];    
    self.userPicker.tag = kUserPickerTag;
    [self.userPicker reloadAllComponents];
    if(userName)
    {
        NSInteger selectedIndex = [userList indexOfObject:userName];
        if(selectedIndex != NSNotFound)
        {
           [self.userPicker selectRow:selectedIndex inComponent:0 animated:YES]; 
        }
    }
    [self showPicker:self.userPicker];
}

-(void) showAccountPicker:(NSString *)accountName
{
    [self._tableView scrollToRowAtIndexPath:selectedIndexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];    
    self.userPicker.tag = kAccountPickerTag;
    [self.userPicker reloadAllComponents];
    if(accountName)
    {
        NSInteger selectedIndex = [accounts indexOfObject:accountName];
        if(selectedIndex != NSNotFound)
        {
            [self.userPicker selectRow:selectedIndex inComponent:0 animated:YES]; 
        }
    }
    [self showPicker:self.userPicker];
}

-(void) showDatePicker:(NSString*) dateText
{    
    if(dateText != nil)
    {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterShortStyle];
        [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
        if ([dateFormatter dateFromString:dateText] != nil) 
        {
            self.datePicker.date = [dateFormatter dateFromString:dateText];
        }
        else 
        {
            self.datePicker.date = [NSDate date];
        }        
    }
    else
        self.datePicker.date = [NSDate date];
    
    [self.view endEditing:YES];//dismiss if there is a keypad
    [self showPicker:self.datePicker];
}

-(void) showKeyboard:(UITableViewCell*) currentCell : (UITableViewCell*) nextCell
{
    EditViewSectionItem *evSectionItem = [editableDataObjectFields objectAtIndex:selectedIndexPath.section];
    DataObjectField *dof  = [evSectionItem.rowItems objectAtIndex:selectedIndexPath.row];
    UITextField *currentTextField = (UITextField *)[currentCell.contentView viewWithTag:1001];
    //[(DataObject *)[_detailedData objectAtIndex:0] setObject:currentTextField.text forFieldName:dof.name];
    [dataSource setObject:currentTextField.text forKey:dof.name];
    UITextField *newTextField = (UITextField *)[nextCell.contentView viewWithTag:1001];
    [newTextField becomeFirstResponder];
}

-(void) handleNextCell:(UITableViewCell*) currentCell :(UITableViewCell*) nextCell :(NSIndexPath*) newIndexPath
{
    if([currentCell.reuseIdentifier isEqualToString:@"date"])
    {
        [self dismissPicker:self.datePicker];
    }
    else if([currentCell.reuseIdentifier isEqualToString:@"time"] || [currentCell.reuseIdentifier isEqualToString:@"assigned_user_name"] || [currentCell.reuseIdentifier isEqualToString:@"account_name"])
    {
        [self dismissPicker:self.userPicker];
    }
    else
    {
        [self dismissKeyboard:nil];
    }
    
   // UITableViewCell *nextCell = [_tableView cellForRowAtIndexPath:newIndexPath];
    [self scrollCell:nextCell];//ScrollCell
    
    if(!nextCell)
    {
        [self dismissKeyboard:nil];
        return;
    }
    if ([nextCell.reuseIdentifier isEqualToString:@"date"])
    {
        UILabel *valueField = (UILabel*)[nextCell.contentView viewWithTag:1001];
        [self showDatePicker:valueField.text]; 
    }
    else if([nextCell.reuseIdentifier isEqualToString:@"time"])
    {
        UILabel *valueField = (UILabel*)[nextCell.contentView viewWithTag:1001];            
        [self showTimePicker:valueField.text];
    }
    else if([nextCell.reuseIdentifier isEqualToString:@"assigned_user_name"])
    {
        UILabel *valueField = (UILabel*)[nextCell.contentView viewWithTag:1001];            
        [self showUserPicker:valueField.text];
    }
    else if([nextCell.reuseIdentifier isEqualToString:@"account_name"])
    {
        UILabel *valueField = (UILabel*)[nextCell.contentView viewWithTag:1001];            
        [self showAccountPicker:valueField.text];
    }
    else
    {
        UITextField *textField = (UITextField *)[nextCell.contentView viewWithTag:1001];
        [textField becomeFirstResponder];
    }
}

-(void)nextPrevious:(id)sender
{
    UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
    NSInteger segItemIndex =  segmentedControl.selectedSegmentIndex;
    UITableViewCell *cell = [_tableView cellForRowAtIndexPath:selectedIndexPath];
    switch (segItemIndex) {
        case kPrevSegementItemIndex:
            //if(selectedIndexPath.row >= 0){
            if([self hasPrevious:selectedIndexPath])
            {
                NSIndexPath* newIndexPath;
                if(selectedIndexPath.section !=0){
                    if(selectedIndexPath.row !=0){
                        newIndexPath = [NSIndexPath indexPathForRow:selectedIndexPath.row-1 inSection:selectedIndexPath.section];
                    }else{
                        newIndexPath = [NSIndexPath indexPathForRow:[_tableView numberOfRowsInSection:selectedIndexPath.section-1]-1 inSection:selectedIndexPath.section-1];
                    }
                }else{
                    if(selectedIndexPath.row !=0){
                        newIndexPath = [NSIndexPath indexPathForRow:selectedIndexPath.row-1 inSection:selectedIndexPath.section];
                    }else{
                        return;
                    }
                }   
                selectedIndexPath = newIndexPath;
                [self handleNextCell:cell :[_tableView cellForRowAtIndexPath:newIndexPath] :newIndexPath];
            }
            break;
        case kNextSegementItemIndex:
            //if(selectedIndexPath.row < [self effectiveRowIndexWithIndexPath:selectedIndexPath])
            if([self hasNext:selectedIndexPath])
            {
                NSIndexPath *newIndexPath;
                if (selectedIndexPath.row+1 >= [_tableView numberOfRowsInSection:selectedIndexPath.section]) {
                    newIndexPath = [NSIndexPath indexPathForRow:0 inSection:selectedIndexPath.section+1];
                }else{
                    newIndexPath = [NSIndexPath indexPathForRow:selectedIndexPath.row+1 inSection:selectedIndexPath.section];
                }                
                
                UITableViewCell *nextCell = [_tableView cellForRowAtIndexPath:newIndexPath];
                [self handleNextCell:cell :nextCell :newIndexPath];
                selectedIndexPath = newIndexPath;
            }
            break;
        default:
            break;
    }
}

-(void)scrollCell:(UITableViewCell*)cell
{
    selectedIndexPath = [_tableView indexPathForCell:cell];
    NSInteger rowIndex = [self effectiveRowIndexWithIndexPath:selectedIndexPath]+selectedIndexPath.row;//[selectedIndexPath row];
    NSInteger rowHeight = (rowIndex + 1)*cell.frame.size.height;
    UIInterfaceOrientation orientation =
    [[UIApplication sharedApplication] statusBarOrientation];
    if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight)
    {
        if(rowHeight < 106){
            _tableView.contentInset =  UIEdgeInsetsZero;
        }
        else{
            _tableView.contentInset =  UIEdgeInsetsMake(0.0, 0.0, rowHeight-106.0, 0.0);
            [_tableView scrollToRowAtIndexPath:[_tableView indexPathForCell:cell] atScrollPosition:UITableViewScrollPositionTop animated:YES ];
        }
    }
    else{
        if(rowHeight < (_tableView.frame.size.height-216-57)){
            _tableView.contentInset =  UIEdgeInsetsZero;
        }
        else{
            _tableView.contentInset =  UIEdgeInsetsMake(0.0, 0.0, rowHeight-(_tableView.frame.size.height-200), 0.0);
            [_tableView scrollToRowAtIndexPath:[_tableView indexPathForCell:cell] atScrollPosition:UITableViewScrollPositionTop animated:YES ];
        }
    }
}

-(void)didTextChanged:(id)sender
{
    UITextField *textField = (UITextField*)sender;
    EditViewSectionItem *evSectionItem = [editableDataObjectFields objectAtIndex:selectedIndexPath.section];
    DataObjectField *dof  = [evSectionItem.rowItems objectAtIndex:selectedIndexPath.row];
    [dataSource setObject:textField.text forKey:dof.name];
    self.navigationItem.rightBarButtonItem.enabled = [self isValidRecord];
}

-(NSInteger)effectiveRowIndexWithIndexPath:(NSIndexPath *)indexpath
{
    int i,rowsCount=0;
    for (i=0; i<indexpath.section; i++) {
        rowsCount += [_tableView numberOfRowsInSection:i]; 
    }
    return rowsCount;
}
-(NSInteger)totalRowsCount
{
    NSInteger rowsCount=0;
    for (NSInteger i=0 ; i<[_tableView numberOfSections]; i++) {
        rowsCount += [_tableView numberOfRowsInSection:i];
    }
    return rowsCount;
}
-(BOOL)hasNext:(NSIndexPath *)indexPath
{
    NSInteger currentRowIndex = [self effectiveRowIndexWithIndexPath:indexPath]+indexPath.row;
    NSInteger totalRowCount = [self totalRowsCount];
    if(currentRowIndex == totalRowCount-1){
        return NO;
    }else{
        return YES;
    }
}
-(BOOL)hasPrevious:(NSIndexPath *)indexPath
{
    NSInteger currentRowIndex = [self effectiveRowIndexWithIndexPath:indexPath]+indexPath.row;
    if (currentRowIndex > 0) {
        return YES;
    }else{
        return NO;
    }
}
@end
