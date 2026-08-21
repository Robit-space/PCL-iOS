#import "PCLModpackImportViewController.h"
#import "PCLModpackImportService.h"
#import "PCLCurseForgeAPI.h"
#import "PCLModrinthAPI.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface PCLModpackImportViewController () <UIDocumentPickerDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSDictionary *> *sources;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *statusLabel;

@end

@implementation PCLModpackImportViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"导入整合包";
    self.view.backgroundColor = [UIColor colorWithRed:251.0/255.0 green:251.0/255.0 blue:251.0/255.0 alpha:1.0];
    
    self.sources = @[
        @{@"title": @"从 Zip 文件导入", @"subtitle": @"选择本地 .zip 或 .mrpack 文件", @"action": @"zip"},
        @{@"title": @"从 CurseForge 导入", @"subtitle": @"输入 CurseForge 项目 ID 和文件 ID", @"action": @"curseforge"},
        @{@"title": @"从 Modrinth 导入", @"subtitle": @"输入 Modrinth 项目 ID 和版本 ID", @"action": @"modrinth"},
    ];
    
    [self setupUI];
}

- (void)setupUI {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.tableView];
    
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressView.hidden = YES;
    [self.view addSubview:self.progressView];
    
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.textColor = [UIColor grayColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.hidden = YES;
    [self.view addSubview:self.statusLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [self.progressView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.progressView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.progressView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-60],
        
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.progressView.topAnchor constant:-8],
    ]];
}

#pragma mark - Import Actions

- (void)importFromZip {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType typeWithIdentifier:@"public.zip-archive"]]];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)importFromCurseForge {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"CurseForge 导入"
                                                                message:@"请输入项目 ID 和文件 ID"
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Project ID (数字)";
        tf.keyboardType = UIKeyboardTypeNumberPad;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"File ID (数字)";
        tf.keyboardType = UIKeyboardTypeNumberPad;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"导入" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSInteger projectID = [alert.textFields[0].text integerValue];
        NSInteger fileID = [alert.textFields[1].text integerValue];
        if (projectID > 0 && fileID > 0) {
            [self startCurseForgeImport:projectID fileID:fileID];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)importFromModrinth {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Modrinth 导入"
                                                                message:@"请输入项目 ID 和版本 ID"
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Project ID (如: Aaol4y3F)";
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Version ID (如: abc123)";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"导入" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *projectID = alert.textFields[0].text;
        NSString *versionID = alert.textFields[1].text;
        if (projectID.length > 0 && versionID.length > 0) {
            [self startModrinthImport:projectID versionID:versionID];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)startCurseForgeImport:(NSInteger)projectID fileID:(NSInteger)fileID {
    self.progressView.hidden = NO;
    self.statusLabel.hidden = NO;
    self.progressView.progress = 0;
    
    [[PCLModpackImportService sharedService] importFromCurseForge:projectID
                                                           fileID:fileID
                                                         progress:^(double progress, NSString *status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressView.progress = progress;
            self.statusLabel.text = status;
        });
    }
                                                       completion:^(BOOL success, PCLModpackImportResult *result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressView.hidden = YES;
            if (success) {
                self.statusLabel.text = [NSString stringWithFormat:@"导入成功: %@", result.instanceName];
            } else {
                self.statusLabel.text = [NSString stringWithFormat:@"导入失败: %@", error.localizedDescription];
            }
        });
    }];
}

- (void)startModrinthImport:(NSString *)projectID versionID:(NSString *)versionID {
    self.progressView.hidden = NO;
    self.statusLabel.hidden = NO;
    self.progressView.progress = 0;
    
    [[PCLModpackImportService sharedService] importFromModrinth:projectID
                                                     versionID:versionID
                                                       progress:^(double progress, NSString *status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressView.progress = progress;
            self.statusLabel.text = status;
        });
    }
                                                     completion:^(BOOL success, PCLModpackImportResult *result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressView.hidden = YES;
            if (success) {
                self.statusLabel.text = [NSString stringWithFormat:@"导入成功: %@", result.instanceName];
            } else {
                self.statusLabel.text = [NSString stringWithFormat:@"导入失败: %@", error.localizedDescription];
            }
        });
    }];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;
    
    self.progressView.hidden = NO;
    self.statusLabel.hidden = NO;
    self.progressView.progress = 0;
    
    [[PCLModpackImportService sharedService] importFromZipAtURL:url
                                                       progress:^(double progress, NSString *status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressView.progress = progress;
            self.statusLabel.text = status;
        });
    }
                                                     completion:^(BOOL success, PCLModpackImportResult *result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressView.hidden = YES;
            if (success) {
                self.statusLabel.text = [NSString stringWithFormat:@"导入成功: %@", result.instanceName];
            } else {
                self.statusLabel.text = [NSString stringWithFormat:@"导入失败: %@", error.localizedDescription];
            }
        });
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sources.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ImportCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ImportCell"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    NSDictionary *source = self.sources[indexPath.row];
    cell.textLabel.text = source[@"title"];
    cell.detailTextLabel.text = source[@"subtitle"];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *action = self.sources[indexPath.row][@"action"];
    if ([action isEqualToString:@"zip"]) {
        [self importFromZip];
    } else if ([action isEqualToString:@"curseforge"]) {
        [self importFromCurseForge];
    } else if ([action isEqualToString:@"modrinth"]) {
        [self importFromModrinth];
    }
}

@end
