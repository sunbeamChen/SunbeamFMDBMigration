//
//  SunbeamDBService.m
//  Pods
//
//  Created by sunbeam on 16/6/21.
//
//

#import "SunbeamDBService.h"

#import <FMDB/FMDB.h>

#import "SunbeamDBMigrationService.h"

/**
 *  SBFMDBMigration exception name
 */
#define SunbeamDBExceptionName @"SunbeamDB exception"

@interface SunbeamDBService()

/**
 *  FMDB数据库实例
 */
@property (nonatomic, strong) FMDatabase* database;

/**
 *  数据库文件具体路径
 */
@property (nonatomic, copy) NSString* databaseFilePath;

/**
 *  SBFMDBMigration数据库迁移服务
 */
@property (nonatomic, strong) SunbeamDBMigrationService* sunbeamDBMigrationService;

@end

@implementation SunbeamDBService

/**
 *  单例实现
 */
sunbeam_singleton_implementation(SunbeamDBService)

#pragma mark - 初始化操作
/**
 *  初始化SBFMDB服务
 *
 *  @param dbFilePath 数据库文件路径
 *  @param dbFileName 数据库文件名称
 */
- (void) initSunbeamDBService:(NSString *) dbFilePath dbFileName:(NSString *) dbFileName
{
    // 创建数据库文件保存路径
    if ([self createFilePath:dbFilePath] == nil) {
        @throw [NSException exceptionWithName:SunbeamDBExceptionName reason:@"db file path create failed" userInfo:nil];
        return;
    }
    
    // 初始化数据库文件具体路径
    self.databaseFilePath = [dbFilePath stringByAppendingPathComponent:dbFileName];
    
    // 数据库初始化，并打开
    [self DBInit];
    
    // 开始执行数据库迁移服务
    [self beginSBFMDBMigration];
}

/**
 *  init FMDB database
 */
- (void)DBInit
{
    if (![self isFileExistInExactFilePath:self.databaseFilePath]) {
        self.database = [FMDatabase databaseWithPath:self.databaseFilePath];
        
        if (!self.database) {
            NSLog(@"创建DB文件失败");
            @throw [NSException exceptionWithName:SunbeamDBExceptionName reason:@"db file create failed" userInfo:nil];
            return;
        }
    } else {
        self.database = [FMDatabase databaseWithPath:self.databaseFilePath];
        
        if (!self.database) {
            NSLog(@"创建FMDBDatabase失败");
            @throw [NSException exceptionWithName:SunbeamDBExceptionName reason:@"FMDB database init failed" userInfo:nil];
            return;
        }
    }
    
    /**
     *  开启数据库读写操作
     */
    [self.database open];
}

/**
 *  获取FMDBDatabase实例
 *
 *  @return FMDBDatabase
 */
- (id) getSBFMDBDatabase
{
    if (self.database == nil) {
        @throw [NSException exceptionWithName:SunbeamDBExceptionName reason:@"FMDB database instance is nil" userInfo:nil];
        return nil;
    }
    
    return self.database;
}

/**
 *  开始执行数据库迁移操作
 */
- (void) beginSBFMDBMigration
{
    self.sunbeamDBMigrationService = [[SunbeamDBMigrationService alloc] initSunbeamDBMigrationService:self customSqlBundleName:nil];
    
    if (self.sunbeamDBMigrationService == nil) {
        @throw [NSException exceptionWithName:SunbeamDBExceptionName reason:@"SBFMDBMigration service is nil" userInfo:nil];
        return;
    }
    
    [self.sunbeamDBMigrationService doSunbeamDBMigration];
}

#pragma mark - SBFMDBMigration delegate
/**
 *  数据库迁移完成，返回迁移的结果（出错后，会返回错误原因）
 */
- (void) completeDBMigration
{
    NSLog(@"数据库迁移成功");
}

#pragma mark - SQL语句执行操作
/**
 *  执行sql语句更新命令
 *
 *  @param sql sql更新语句
 *
 *  @return 执行结果
 */
- (BOOL) executeTransactionSBFMDBUpdate:(NSString*)sql, ...
{
    va_list args;
    va_start(args, sql);
    
    [self.database beginTransaction];
    
    BOOL result = [self.database executeUpdate:sql withVAList:args];
    
    if (result) {
        [self.database commit];
    } else {
        [self.database rollback];
    }
    
    va_end(args);
    return result;
}

/**
 *  执行sql语句查询命令
 *
 *  @param sql sql查询语句
 *
 *  @return 查询结果
 */
- (NSMutableArray *) executeSBFMDBQuery:(NSString*)sql, ...
{
    va_list args;
    va_start(args, sql);
    
    FMResultSet* result = [self.database executeQuery:sql withVAList:args];
    
    NSMutableArray* array = [NSMutableArray array];
    
    while ([result next]) {
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        
        for (int i=0; i<result.columnCount; ++i) {
            dic[[result columnNameForIndex:i]] = [result stringForColumnIndex:i];
        }
        
        [array addObject:dic];
    }
    
    va_end(args);
    return array;
}

#pragma mark - private method
/**
 *  创建数据库文件保存路径
 */
- (NSString *) createFilePath:(NSString *)filePath
{
    if (filePath == nil || [@"" isEqualToString:filePath]) {
        return nil;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filePath]) {
        NSError *error = nil;
        [fileManager createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            return nil;
        }
    }
    
    return filePath;
}

/**
 *  查找指定路径下是否存在指定文件
 */
- (BOOL) isFileExistInExactFilePath:(NSString *)filePath
{
    if (filePath == nil || [@"" isEqualToString:filePath]) {
        return NO;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    return [fileManager fileExistsAtPath:filePath];
}

@end
