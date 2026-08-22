#import "PCLInstanceSelectViewController.h"
#import "PCLInstanceManager.h"
#import "PCLInstanceEditViewController.h"
#import "PCLVersionManager.h"
#import "PCLModpackImportViewController.h"

static UIColor *C(NSUInteger x) {
    return [UIColor colorWithRed:((x>>16)&255)/255.0
        green:((x>>8)&255)/255.0 blue:(x&255)/255.0 alpha:1];
}

@interface PCLInstanceSelectViewController ()
<UITableViewDataSource,UITableViewDelegate,UISearchBarDelegate>
@property UIView *leftPanel;
@property UIView *rightPanel;
@property UISearchBar *searchBar;
@property UITableView *tableView;
@property UIView *emptyCard;
@property UILabel *emptyTitle;
@property UILabel *emptyText;
@property UIButton *emptyDownload;
@property UIButton *createButton;
@property NSArray<PCLInstance *> *instances;
@property NSArray<PCLInstance *> *shown;
@property NSString *selectedName;
@end

@implementation PCLInstanceSelectViewController


- (void)viewDidLoad {

    [super viewDidLoad];

    self.view.backgroundColor=UIColor.clearColor;

    [self buildLeft];

    [self buildRight];

    [self reloadInstances];

}

- (UIButton *)button:(NSString *)title

                icon:(NSString *)icon

              action:(SEL)action {

    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];

    [b setTitle:title forState:UIControlStateNormal];

    [b setImage:[UIImage systemImageNamed:icon]

       forState:UIControlStateNormal];

    [b setTitleColor:C(0x343D4A) forState:UIControlStateNormal];

    b.tintColor=C(0x343D4A);

    b.contentHorizontalAlignment=

        UIControlContentHorizontalAlignmentLeft;

    b.titleLabel.font=[UIFont systemFontOfSize:13

        weight:UIFontWeightMedium];

    [b addTarget:self action:action

        forControlEvents:UIControlEventTouchUpInside];

    return b;

}


- (void)buildLeft {
    self.leftPanel=[[UIView alloc] init];
    self.leftPanel.backgroundColor=
        [UIColor colorWithWhite:.98 alpha:.96];
    [self.view addSubview:self.leftPanel];

    UILabel *title=[[UILabel alloc] init];
    title.tag=102;
    title.text=@"Minecraft 文件夹";
    title.font=[UIFont systemFontOfSize:12
        weight:UIFontWeightSemibold];
    title.textColor=C(0x697482);
    [self.leftPanel addSubview:title];

    UIView *folder=[[UIView alloc] init];
    folder.tag=103;
    folder.backgroundColor=C(0xE8F0FE);
    folder.layer.cornerRadius=6;
    folder.layer.borderWidth=0;
    folder.layer.borderColor=C(0x1370F3).CGColor;
    [self.leftPanel addSubview:folder];


    UILabel *name=[[UILabel alloc] init];

    name.tag=104;

    name.text=@".minecraft";

    name.font=[UIFont systemFontOfSize:14

        weight:UIFontWeightSemibold];

    name.textColor=C(0x343D4A);

    [folder addSubview:name];

    UILabel *path=[[UILabel alloc] init];

    path.tag=105;

    path.text=[[PCLVersionManager sharedManager] gamesDirectory];

    path.font=[UIFont systemFontOfSize:10.5];

    path.textColor=C(0x6F7A88);

    path.lineBreakMode=NSLineBreakByTruncatingMiddle;

    [folder addSubview:path];

    UILabel *addTitle=[[UILabel alloc] init];

    addTitle.tag=106; addTitle.text=@"添加或导入";

    addTitle.font=[UIFont systemFontOfSize:12];

    addTitle.textColor=C(0x697482);

    [self.leftPanel addSubview:addTitle];

    self.createButton=[self button:@"导入整合包" icon:@"shippingbox.and.arrow.down" action:@selector(importPressed)];

    self.createButton.tag=107;

    [self.leftPanel addSubview:self.createButton];

}



- (void)buildRight {
    self.rightPanel=[[UIView alloc] init];
    [self.view addSubview:self.rightPanel];

    self.searchBar=[[UISearchBar alloc] init];
    self.searchBar.delegate=self;
    self.searchBar.placeholder=@"搜索实例";
    self.searchBar.searchBarStyle=UISearchBarStyleMinimal;
    [self.rightPanel addSubview:self.searchBar];

    self.tableView=[[UITableView alloc]
        initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.backgroundColor=UIColor.clearColor;
    self.tableView.separatorStyle=
        UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight=44;
    self.tableView.contentInset=
        UIEdgeInsetsMake(0,7,10,7);
    self.tableView.dataSource=self;
    self.tableView.delegate=self;
    [self.rightPanel addSubview:self.tableView];

    self.emptyCard=[[UIView alloc] init];
    self.emptyCard.backgroundColor=[UIColor colorWithWhite:1 alpha:.88];
    self.emptyCard.layer.cornerRadius=6;
    [self.rightPanel addSubview:self.emptyCard];

    self.emptyTitle=[[UILabel alloc] init];
    self.emptyTitle.textAlignment=NSTextAlignmentCenter;
    self.emptyTitle.textColor=C(0x1370F3);
    self.emptyTitle.font=[UIFont systemFontOfSize:19];
    [self.emptyCard addSubview:self.emptyTitle];
    UIView *line=[[UIView alloc] init]; line.tag=201;

    line.backgroundColor=C(0x1370F3); [self.emptyCard addSubview:line];

    self.emptyText=[[UILabel alloc] init]; self.emptyText.numberOfLines=0;

    self.emptyText.textAlignment=NSTextAlignmentCenter;

    self.emptyText.font=[UIFont systemFontOfSize:13];

    [self.emptyCard addSubview:self.emptyText];



    self.emptyDownload=[UIButton buttonWithType:UIButtonTypeSystem];
    [self.emptyDownload setTitle:@"下载游戏" forState:UIControlStateNormal];
    [self.emptyDownload addTarget:self action:@selector(downloadPressed)
        forControlEvents:UIControlEventTouchUpInside];
    [self.emptyCard addSubview:self.emptyDownload];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w=self.view.bounds.size.width;
    CGFloat h=self.view.bounds.size.height;
    CGFloat leftW=self.leftPanelWidth>0?self.leftPanelWidth:w*.35;
    self.leftPanel.frame=CGRectMake(0,0,leftW,h);
    self.rightPanel.frame=CGRectMake(leftW,0,w-leftW,h);
    [self.leftPanel viewWithTag:102].frame=CGRectMake(13,18,leftW-26,18);

    UIView *folder=[self.leftPanel viewWithTag:103];
    folder.frame=CGRectMake(10,43,leftW-20,44);
    [folder viewWithTag:104].frame=CGRectMake(14,4,leftW-54,19);
    [folder viewWithTag:105].frame=CGRectMake(14,23,leftW-54,15);
    [self.leftPanel viewWithTag:106].frame=CGRectMake(13,101,leftW-26,18);
    self.createButton.frame=CGRectMake(10,123,leftW-20,34);
    [self.leftPanel viewWithTag:107].frame=CGRectMake(10,123,leftW-20,34);

    CGFloat rw=self.rightPanel.bounds.size.width;
    self.searchBar.frame=CGRectMake(25,15,rw-50,36);
    self.tableView.frame=CGRectMake(0,63,rw,h-63);
    CGFloat cw=MIN(420,MAX(260,rw-80));
    self.emptyCard.frame=CGRectMake((rw-cw)/2,(h-156)/2,cw,156);
    self.emptyTitle.frame=CGRectMake(20,17,cw-40,28);
    [self.emptyCard viewWithTag:201].frame=CGRectMake(20,52,cw-40,2);
    self.emptyText.frame=CGRectMake(24,67,cw-48,35);
    self.emptyDownload.frame=CGRectMake((cw-140)/2,111,140,35);
}

- (PCLInstance *)temporaryInstance:(PCLVersionInfo *)v {
    PCLInstance *i=[[PCLInstance alloc] init];
    i.name=v.versionId;
    i.versionId=v.versionId;
    i.gameDir=[[PCLInstanceManager sharedManager] sharedGameDirectory];
    return i;
}

- (void)reloadInstances {
    PCLInstanceManager *m=[PCLInstanceManager sharedManager];
    NSMutableArray *all=[[m allInstances] mutableCopy];
    NSMutableSet *used=[NSMutableSet set];
    for(PCLInstance *i in all)
        if(i.versionId.length)[used addObject:i.versionId];

    for(PCLVersionInfo *v in [[PCLVersionManager sharedManager] localVersions])
        if(![used containsObject:v.versionId])
            [all addObject:[self temporaryInstance:v]];
    self.instances=[all sortedArrayUsingComparator:
        ^NSComparisonResult(PCLInstance *a,PCLInstance *b){
        return [a.name localizedCaseInsensitiveCompare:b.name];
    }];
    self.selectedName=m.currentInstance.name;
    [self applyFilter];
}

- (void)applyFilter {
    NSString *q=[self.searchBar.text
        stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(!q.length)self.shown=self.instances;
    else self.shown=[self.instances filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(PCLInstance *i,NSDictionary *x){
        return [i.name localizedCaseInsensitiveContainsString:q]||
               [i.versionId localizedCaseInsensitiveContainsString:q];
    }]];

    BOOL found=self.shown.count>0;
    self.tableView.hidden=!found;
    self.emptyCard.hidden=found;
    self.searchBar.hidden=self.instances.count==0;
    self.emptyTitle.text=self.instances.count?
        @"没有搜索结果":@"没有可用实例";
    self.emptyText.text=self.instances.count?
        @"请尝试其他关键词。":@"下载游戏后，实例会显示在这里。";
    self.emptyDownload.hidden=self.instances.count>0;
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    return self.shown.count;
}
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {
    return @"常规实例";
}

- (UITableViewCell *)tableView:(UITableView *)t
        cellForRowAtIndexPath:(NSIndexPath *)x {
    static NSString *ID=@"PCLInstanceCell";
    UITableViewCell *c=[t dequeueReusableCellWithIdentifier:ID];
    if(!c)c=[[UITableViewCell alloc]
        initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:ID];
    PCLInstance *i=self.shown[x.row];
    c.textLabel.text=i.name;
    c.detailTextLabel.text=[NSString stringWithFormat:@"Minecraft %@",i.versionId];

    c.imageView.image=[UIImage systemImageNamed:@"cube.fill"];
    c.imageView.tintColor=C(0x1370F3);
    c.backgroundColor=[UIColor colorWithWhite:1 alpha:.88];
    c.accessoryType=[i.name isEqualToString:self.selectedName]?
        UITableViewCellAccessoryCheckmark:
        UITableViewCellAccessoryDetailButton;
    return c;
}

- (PCLInstance *)persist:(PCLInstance *)i {
    PCLInstanceManager *m=[PCLInstanceManager sharedManager];
    PCLInstance *saved=[m instanceWithName:i.name];
    if(!saved&&[m createInstanceWithName:i.name versionId:i.versionId])
        saved=[m instanceWithName:i.name];
    return saved;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)x {
    PCLInstance *i=[self persist:self.shown[x.row]];
    if(!i)return;
    [[PCLInstanceManager sharedManager] selectInstance:i];
    [NSUserDefaults.standardUserDefaults
        setObject:i.name forKey:@"PCLSelectedInstance"];
    self.selectedName=i.name;
    [self.tableView reloadData];
    if(self.onSelect)self.onSelect(i);
}

- (void)tableView:(UITableView *)t
 accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)x {
    PCLInstance *i=self.shown[x.row];
    UIAlertController *m=[UIAlertController
        alertControllerWithTitle:i.name message:i.versionId
        preferredStyle:UIAlertControllerStyleActionSheet];
    [m addAction:[UIAlertAction actionWithTitle:@"实例设置"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){
        [self editInstance:i];
    }]];

    [m addAction:[UIAlertAction actionWithTitle:@"删除实例"
        style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a){
        [self deleteInstance:i];
    }]];
    [m addAction:[UIAlertAction actionWithTitle:@"取消"
        style:UIAlertActionStyleCancel handler:nil]];
    m.popoverPresentationController.sourceView=[t cellForRowAtIndexPath:x];
    [self presentViewController:m animated:YES completion:nil];
}

- (void)editInstance:(PCLInstance *)i {
    PCLInstance *saved=[self persist:i];
    if(!saved)return;
    PCLInstanceEditViewController *e=
        [[PCLInstanceEditViewController alloc] initWithInstance:saved];
    __weak typeof(self) w=self;
    e.onSaved=^{[w reloadInstances];};
    UINavigationController *n=[[UINavigationController alloc]
        initWithRootViewController:e];
    [self presentViewController:n animated:YES completion:nil];
}

- (void)deleteInstance:(PCLInstance *)i {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"删除实例"
        message:@"将删除该实例及其配置。"
        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"删除"
        style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *x){
        [[PCLInstanceManager sharedManager] deleteInstanceWithName:i.name];
        [NSUserDefaults.standardUserDefaults
            removeObjectForKey:@"PCLSelectedInstance"];
        [self reloadInstances];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"取消"
        style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)createPressed {
    NSArray *v=[[PCLVersionManager sharedManager] localVersions];
    if(!v.count){[self downloadPressed];return;}
    PCLVersionInfo *base=v.firstObject;
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"新建实例"
        message:base.versionId preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *f){
        f.text=base.versionId;
    }];

    [a addAction:[UIAlertAction actionWithTitle:@"创建"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x){
        NSString *name=a.textFields.firstObject.text;
        if(name.length)[[PCLInstanceManager sharedManager]
            createInstanceWithName:name versionId:base.versionId];
        [self reloadInstances];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消"
        style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)importPressed {
    PCLModpackImportViewController *v=[[PCLModpackImportViewController alloc] init];
    v.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemClose
        target:self action:@selector(closeImport)];
    UINavigationController *n=[[UINavigationController alloc] initWithRootViewController:v];
    [self presentViewController:n animated:YES completion:nil];
}
- (void)closeImport {[self dismissViewControllerAnimated:YES completion:nil];}

- (void)searchBar:(UISearchBar *)s textDidChange:(NSString *)t {
    [self applyFilter];
}
- (void)backPressed {if(self.onBack)self.onBack();}
- (void)downloadPressed {if(self.onDownload)self.onDownload();}
@end
