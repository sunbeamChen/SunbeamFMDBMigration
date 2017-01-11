//
//  SunbeamDBService.m
//  Pods
//
//  Created by sunbeam on 16/6/21.
//
//

#import "SunbeamDBService.h"

/**
 *  FMDB数据库服务
 */
#import <FMDB/FMDB.h>

@interface SunbeamDBService()

/**
 *  FMDB数据库实例
 */
@property (nonatomic, strong) FMDatabase* database;

/**
 *  FMDB dataQueue
 */
@property (nonatomic, strong) FMDatabaseQueue* databaseQueue;

/**
 *  是否使用database queue
 */
@property (nonatomic, assign) BOOL useDatabaseQueue;

/**
 *  数据库文件具体路径
 */
@property (nonatomic, copy) NSString* databaseFilePath;

@end

@implementation SunbeamDBService

+ (SunbeamDBService *) sharedSunbeamDBService
{
    static SunbeamDBService *sharedInstance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark - 初始化操作
/**
 *  初始化SBFMDB服务
 *
 *  @param dbFilePath 数据库文件路径
 *  @param dbFileName 数据库文件名称
 */
- (NSError *) createFMDBService:(NSString *) dbFilePath dbFileName:(NSString *) dbFileName useDatabaseQueue:(BOOL) useDatabaseQueue
{
    // 创建数据库文件保存路径
    if ([self createFilePath:dbFilePath] == nil) {
        return [NSError errorWithDomain:@"FMDB service error domain" code:20000 userInfo:@{NSLocalizedDescriptionKey:@"db file path create failed"}];
    }
    // 初始化数据库文件具体路径
    self.databaseFilePath = [dbFilePath stringByAppendingPathComponent:dbFileName];
    self.useDatabaseQueue = useDatabaseQueue;
    if (useDatabaseQueue) {
        return [self DBQueueInit];
    } else {
        return [self DBInit];
    }
}

/**
 *  init FMDB database
 */
- (NSError *)DBInit
{
    if (![self isFileExistInExactFilePath:self.databaseFilePath]) {
        self.database = [FMDatabase databaseWithPath:self.databaseFilePath];
        if (!self.database) {
            return [NSError errorWithDomain:@"FMDB service error domain" code:20001 userInfo:@{NSLocalizedDescriptionKey:@"db file create failed"}];
        }
    } else {
        self.database = [FMDatabase databaseWithPath:self.databaseFilePath];
        if (!self.database) {
            return [NSError errorWithDomain:@"FMDB service error domain" code:20002 userInfo:@{NSLocalizedDescriptionKey:@"db init failed"}];
        }
    }
    [self.database open];
    
    return nil;
}

/**
 *  init FMDB database queue
 */
- (NSError *) DBQueueInit
{
    if (![self isFileExistInExactFilePath:self.databaseFilePath]) {
        self.databaseQueue = [FMDatabaseQueue databaseQueueWithPath:self.databaseFilePath];
        if (!self.databaseQueue) {
            return [NSError errorWithDomain:@"FMDB service error domain" code:20001 userInfo:@{NSLocalizedDescriptionKey:@"db file create failed"}];
        }
    } else {
        self.databaseQueue = [FMDatabaseQueue databaseQueueWithPath:self.databaseFilePath];
        if (!self.databaseQueue) {
            return [NSError errorWithDomain:@"FMDB service error domain" code:20002 userInfo:@{NSLocalizedDescriptionKey:@"db init failed"}];
        }
    }
    
    return nil;
}

#pragma mark - SQL语句执行操作
/**
 *  执行sql语句更新命令
 *
 *  @param sql sql更新语句
 *
 *  @return 执行结果
 */
- (BOOL) executeTransactionSunbeamDBUpdate:(NSString*)sql, ...
{
    va_list args;
    va_start(args, sql);
    
    int numberOfArgs = (int)[[sql componentsSeparatedByString:@"?"] count] - 1;
    
    __block NSMutableArray* list = [[NSMutableArray alloc] init];
    
    while (numberOfArgs--) {
        id object = va_arg(args, id);
        if (object) {
            [list addObject:object];
        } else {
            [list addObject:@""];
        }
    }
    
    va_end(args);
    
    __block BOOL result = NO;
    
    if (self.useDatabaseQueue) {
        [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            result = [db executeUpdate:sql withArgumentsInArray:[list copy]];
            if (!result) {
                NSLog(@"数据库错误:%@", db.lastErrorMessage);
                *rollback = YES;
                return;
            }
        }];
    } else {
        [self.database beginTransaction];
        
        result = [self.database executeUpdate:sql withVAList:args];
        if (result) {
            [self.database commit];
        } else {
            NSLog(@"数据库错误:%@", self.database.lastErrorMessage);
            [self.database rollback];
        }
    }
    
    return result;
}

/**
 执行sql statement语句
 
 @param sqlStatements sql语句
 @return yes/no
 */
- (BOOL) executeTransactionSunbeamDBStatements:(NSString *) sqlStatements
{
    __block BOOL result = NO;
    if (self.useDatabaseQueue) {
        [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            result = [db executeStatements:sqlStatements];
            if (!result) {
                NSLog(@"数据库错误:%@", db.lastErrorMessage);
                *rollback = YES;
                return ;
            }
        }];
    } else {
        [self.database beginTransaction];
        
        result = [self.database executeStatements:sqlStatements];
        if (result) {
            [self.database commit];
        } else {
            NSLog(@"数据库错误:%@", self.database.lastErrorMessage);
            [self.database rollback];
        }
    }
    
    return result;
}

/**
 *  执行sql语句查询命令
 *
 *  @param sql sql查询语句
 *
 *  @return 查询结果
 */
- (NSMutableArray *) executeSunbeamDBQuery:(NSString*)sql, ...
{
    va_list args;
    va_start(args, sql);
    
    int numberOfArgs = (int)[[sql componentsSeparatedByString:@"?"] count] - 1;
    
    __block NSMutableArray* list = [[NSMutableArray alloc] init];
    
    while (numberOfArgs--) {
        id object = va_arg(args, id);
        if (object) {
            [list addObject:object];
        } else {
            [list addObject:@""];
        }
    }
    
    va_end(args);
    
    __block NSMutableArray* array = [NSMutableArray array];
    
    if (self.useDatabaseQueue) {
        [self.databaseQueue inDatabase:^(FMDatabase *db) {
            
            FMResultSet* result = [db executeQuery:sql withArgumentsInArray:[list copy]];
            
            while ([result next]) {
                NSMutableDictionary *dic = [NSMutableDictionary dictionary];
                
                for (int i=0; i<result.columnCount; ++i) {
                    dic[[result columnNameForIndex:i]] = [result stringForColumnIndex:i];
                }
                
                [array addObject:dic];
            }
        }];
    } else {
        FMResultSet* result = [self.database executeQuery:sql withVAList:args];
        
        while ([result next]) {
            NSMutableDictionary *dic = [NSMutableDictionary dictionary];
            
            for (int i=0; i<result.columnCount; ++i) {
                dic[[result columnNameForIndex:i]] = [result stringForColumnIndex:i];
            }
            
            [array addObject:dic];
        }
    }
    
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
