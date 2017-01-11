//
//  SunbeamViewController.m
//  SunbeamFMDBMigration
//
//  Created by sunbeamChen on 06/21/2016.
//  Copyright (c) 2016 sunbeamChen. All rights reserved.
//

#import "SunbeamViewController.h"
#import <SunbeamFMDBMigration/SunbeamFMDBMigration.h>

#define SERVICE_DB_FILE_PATH @"/sherlock/lock/db/"

#define FILE_PATH [NSString stringWithFormat:@"%@%@",[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)objectAtIndex:0], SERVICE_DB_FILE_PATH]

#define DATABASE_NAME @"sherlock.sqlite"

@interface SunbeamViewController () <SunbeamDBMigrationDelegate>

@end

@implementation SunbeamViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    NSError* error = [[[SunbeamDBMigrationService alloc] initSunbeamDBMigrationService:self customSqlBundleName:nil dbFilePath:FILE_PATH dbFileName:DATABASE_NAME] doSunbeamDBMigration];
    NSLog(@"迁移结果:%@", error);
    
//    NSMutableString* sqlstatement = [NSMutableString stringWithString:@""];
//    NSString* sql1 = @"CREATE TABLE IF NOT EXISTS hello (x text);";
//    NSString* sql2 = @"CREATE TABLE IF NOT EXISTS sunbeam (y text);";
//    NSString* sql3 = @"INSERT INTO hello (x) values ('XXX');";
//    NSString* sql4 = @"INSERT INTO sunbeam (y,x) values ('YYY','xxx');";
//    [sqlstatement appendString:sql1];
//    [sqlstatement appendString:sql2];
//    [sqlstatement appendString:sql3];
//    [sqlstatement appendString:sql4];
//    
//    [[SunbeamDBService sharedSunbeamDBService] executeTransactionSunbeamDBStatements:sqlstatement];
}

@end
