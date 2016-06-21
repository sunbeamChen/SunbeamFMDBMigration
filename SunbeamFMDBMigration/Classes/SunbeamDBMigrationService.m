//
//  SunbeamDBMigrationService.m
//  Pods
//
//  Created by sunbeam on 16/6/21.
//
//

#import "SunbeamDBMigrationService.h"

/**
 *  数据库服务
 */
#import "SunbeamDBService.h"

/**
 *  是否首次初始化
 */
typedef NS_ENUM(NSInteger, SunbeamDBInitStatus) {
    /**
     *  首次初始化
     */
    SunbeamDBInitStatusFirst = 0,
    
    /**
     *  数据库升级
     */
    SunbeamDBInitStatusUpgrade = 1,
    
    /**
     *  没有更新
     */
    SunbeamDBInitStatusNoUpdate = 2,
};

/**
 *  SBFMDBMigration exception name
 */
#define SunbeamDBMigrationExceptionName @"SunbeamDBMigration exception"

/**
 *  默认sql bundle名称
 */
#define SQL_BUNDLE_NAME_DEFAULT @"SunbeamDBMigrationSQL.bundle"

/**
 *  tb_sql数据库迁移标识字段value
 */
#define SQL_TABLE_SQL_FLAG_COLUMN_VALUE @"sb_sql_flag"

/**
 *  tb_sql数据库迁移标识字段名称
 */
#define SQL_TABLE_SQL_VERSION_COLUMN_NAME @"sql_version"

/**
 *  default sb_version
 */
#define SB_VERSION_DEFAULT @"0"

/**
 *  查询tb_sql表是否存在
 */
#define SELECT_SQL_TABLE_EXIST @"SELECT name FROM sqlite_master WHERE type='table' AND name='tb_sql'"

/**
 *  tb_sql表创建sql语句
 */
#define CREATE_SQL_TABLE @"CREATE TABLE IF NOT EXISTS 'tb_sql' ('sql_flag' VARCHAR(80), 'sql_version' VARCHAR(80))"

/**
 *  tb_sql插入sql语句
 */
#define INSERT_SQL_TABLE @"INSERT INTO tb_sql (sql_flag,sql_version) VALUES (?,?)"

/**
 *  tb_sql更新sql语句
 */
#define UPDATE_SQL_VERSION_BY_SQL_FLAG @"UPDATE tb_sql SET sql_version=? WHERE sql_flag=?"

/**
 *  tb_sql查询sql语句
 */
#define SELECT_SQL_VERSION_BY_SQL_FLAG @"SELECT sql_version FROM tb_sql WHERE sql_flag=?"

/**
 *  sql file name regex
 */
static NSString *const SQLFilenameRegexString = @"^(\\d+)\\.sql$";

@interface SunbeamDBMigrationService()

/**
 *  数据库迁移服务代理
 */
@property (nonatomic, weak, readwrite) id<SunbeamDBMigrationDelegate> delegate;

/**
 *  自定义sql bundle名称
 */
@property (nonatomic, copy, readwrite) NSString* customSqlBundleName;

/**
 *  是否首次升级数据库
 */
@property (nonatomic, assign) SunbeamDBInitStatus dbInitStatus;

@end

@implementation SunbeamDBMigrationService

- (NSString *)libName
{
    return @"sunbeam FMDB migration";
}

- (NSString *)libDesc
{
    return @"an database upgrade strategy for APP upgrade";
}

- (NSString *)libVersion
{
    return SUNBEAM_DB_MIGRATION_LIB_VERSION;
}

- (instancetype)initSunbeamDBMigrationService:(id<SunbeamDBMigrationDelegate>)delegate customSqlBundleName:(NSString *)customSqlBundleName
{
    if (self = [super init]) {
        self.delegate = delegate;
        self.customSqlBundleName = customSqlBundleName;
    }
    
    return self;
}

- (void)doSunbeamDBMigration
{
    if (self.delegate == nil) {
        @throw [NSException exceptionWithName:SunbeamDBMigrationExceptionName reason:@"SBFMDBMigration delegate should not be nil." userInfo:nil];
        return;
    }
    
    if (self.customSqlBundleName == nil || [@"" isEqualToString:self.customSqlBundleName]) {
        self.customSqlBundleName = SQL_BUNDLE_NAME_DEFAULT;
    }
    
    if ([self.delegate respondsToSelector:@selector(prepareDBMigration)]) {
        [self.delegate prepareDBMigration];
    } else {
        [self prepareDBMigration];
    }
    
    if ([self.delegate respondsToSelector:@selector(executeDBMigration)]) {
        [self.delegate executeDBMigration];
    } else {
        [self executeDBMigration];
    }
    
    [self completeDBMigration];
}

#pragma mark - prepare db migration
- (void) prepareDBMigration
{
    // 检查用户是否为lastSQLVersion赋值
    if (self.lastSQLVersion == nil) {
        // 用户没有为lastSQLVersion赋值
        [self initLastSQLVersion];
    }
    
    // 初始化bundle文件，lastDBTableDictionary & currentDBTableDictionary
    [self initDBTableDictionary];
    
    // 本次APP没有数据需要升级，直接返回
    if (self.dbInitStatus == SunbeamDBInitStatusNoUpdate) {
        return;
    }
    
    // 对比查询哪些字段有添加、删除
    [self initTableParamsDictionary:self.dbInitStatus];
}

/**
 *  初始化lastSQLVersion
 */
- (void) initLastSQLVersion
{
    // 检查tb_sql表是否存在
    if ([self checkSQLTableExist]) {
        // 初始化lastSQLVersion
        self.lastSQLVersion = [self selectLastSQLVersionFromSQLTable];
        
        if (!self.lastSQLVersion) {
            @throw [NSException exceptionWithName:SunbeamDBMigrationExceptionName reason:@"last sql version should not be nil while tb_sql is exist." userInfo:nil];
            return;
        }
        
        // 表存在，表示当前数据库处于待升级状态
        self.dbInitStatus = SunbeamDBInitStatusUpgrade;
    } else {
        // 创建tb_sql
        if (![self createSQLTable]) {
            @throw [NSException exceptionWithName:SunbeamDBMigrationExceptionName reason:@"tb_sql table create failed." userInfo:nil];
            return;
        }
        
        // 初始化lastSQLVersion
        self.lastSQLVersion = SB_VERSION_DEFAULT;
        
        // 将初始化值插入tb_sql
        if (![self initSQLVersion]) {
            @throw [NSException exceptionWithName:SunbeamDBMigrationExceptionName reason:@"tb_sql data init failed." userInfo:nil];
            return;
        }
        
        // 表不存在，表示当前数据库处于初始化状态
        self.dbInitStatus = SunbeamDBInitStatusFirst;
    }
}

/**
 *  检查tb_sql表是否存在
 */
- (BOOL) checkSQLTableExist
{
    NSMutableArray* array = [[SunbeamDBService sharedSunbeamDBService] executeSunbeamDBQuery:SELECT_SQL_TABLE_EXIST];
    
    if (array != nil && [array count] > 0) {
        return YES;
    }
    
    return NO;
}

/**
 *  从tb_sql表中查询lastSQLVersion
 */
- (NSString *) selectLastSQLVersionFromSQLTable
{
    NSMutableArray* array = [[SunbeamDBService sharedSunbeamDBService] executeSunbeamDBQuery:SELECT_SQL_VERSION_BY_SQL_FLAG, SQL_TABLE_SQL_FLAG_COLUMN_VALUE];
    
    if ([array count] != 1) {
        return nil;
    }
    
    return [[array objectAtIndex:0] objectForKey:SQL_TABLE_SQL_VERSION_COLUMN_NAME];
}

/**
 *  创建tb_sql
 */
- (BOOL) createSQLTable
{
    if ([[SunbeamDBService sharedSunbeamDBService] executeTransactionSunbeamDBUpdate:CREATE_SQL_TABLE]) {
        return YES;
    }
    
    return NO;
}

/**
 *  插入tb_sql初始化数据
 */
- (BOOL) initSQLVersion
{
    if ([[SunbeamDBService sharedSunbeamDBService] executeTransactionSunbeamDBUpdate:INSERT_SQL_TABLE, SQL_TABLE_SQL_FLAG_COLUMN_VALUE, self.lastSQLVersion]) {
        return YES;
    }
    
    return NO;
}

/**
 *  初始化bundle文件，lastDBTableDictionary & currentDBTableDictionary
 */
- (void) initDBTableDictionary
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString* sqlFilePath = [[NSBundle mainBundle] pathForResource:self.customSqlBundleName ofType:@""];
    
    if (![fileManager fileExistsAtPath:sqlFilePath]) {
        @throw [NSException exceptionWithName:SunbeamDBMigrationExceptionName reason:@"sql bundle file is none exist." userInfo:nil];
        return;
    }
    
    NSMutableArray* sqlNameKeyArray = [[NSMutableArray alloc] init];
    
    // check sql bundle has sql file or not, filter sql file name
    NSEnumerator *childFileEnumerator = [[fileManager subpathsAtPath:sqlFilePath] objectEnumerator];
    
    NSRegularExpression *sqlFilenameRegex = [NSRegularExpression regularExpressionWithPattern:SQLFilenameRegexString options:0 error:nil];
    
    NSString *fileName = @"";
    
    while ((fileName = [childFileEnumerator nextObject]) != nil){
        NSString* fileComponent = [fileName lastPathComponent];
        
        if ([sqlFilenameRegex rangeOfFirstMatchInString:fileComponent options:0 range:NSMakeRange(0, [fileComponent length])].location != NSNotFound) {
            [sqlNameKeyArray addObject:[fileComponent stringByDeletingPathExtension]];
        }
    }
    
    if ([sqlNameKeyArray count] == 0) {
        @throw [NSException exceptionWithName:SunbeamDBMigrationExceptionName reason:@"sql file is nil." userInfo:nil];
        return;
    }
    
    // sqlNameKeyArray排序
    NSArray* sqlNameKeySortedArray = [sqlNameKeyArray sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    
    self.currentSQLVersion = [sqlNameKeySortedArray lastObject];
    
    if (self.currentSQLVersion != nil) {
        if ([self.currentSQLVersion integerValue] <= [self.lastSQLVersion integerValue]) {
            // 当前解析版本小于上次升级版本，表示本次APP数据库不需要升级，直接返回
            self.dbInitStatus = SunbeamDBInitStatusNoUpdate;
            return;
        } else {
            // 初始化本次SQL更新文件
            [self initDBTableDictionary:self.currentDBTableDictionary sqlFilePath:sqlFilePath sqlFileName:self.currentSQLVersion];
        }
    } else {
        @throw [NSException exceptionWithName:SunbeamDBMigrationExceptionName reason:@"currentSQLFileName is nil." userInfo:nil];
    }
    
    // 初始化上次SQL更新文件
    if (self.dbInitStatus == SunbeamDBInitStatusFirst) {
        self.lastDBTableDictionary = nil;
    } else {
        [self initDBTableDictionary:self.lastDBTableDictionary sqlFilePath:sqlFilePath sqlFileName:self.lastSQLVersion];
    }
}

// 初始化数据库表至字典中 {"tb_user":["userId","userName",...]}
- (void) initDBTableDictionary:(NSMutableDictionary *) dbTableInitDict sqlFilePath:(NSString *) sqlFilePath sqlFileName:(NSString *) sqlFileName
{
    NSString* filePath = [NSString stringWithFormat:@"%@/%@.sql", sqlFilePath, sqlFileName];
    
    NSString * sqlCommandString = [[NSString alloc] initWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    
    NSArray * sqlCommands = [sqlCommandString componentsSeparatedByString:@";"];
    
    for(NSString* command in sqlCommands) {
        NSString * trimmedCommand = [command stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if ([trimmedCommand length] == 0) {
            continue;
        }
        
        NSLog(@"%@ command is : %@", sqlFileName, trimmedCommand);
        
        NSMutableArray* tableStringArray = [NSMutableArray arrayWithArray:[trimmedCommand componentsSeparatedByString:@"|"]];
        
        NSString* key = [tableStringArray objectAtIndex:0];
        
        [tableStringArray removeObjectAtIndex:0];
        
        [dbTableInitDict setObject:tableStringArray forKey:key];
    }
}

// 初始化对应数据库表增加、删除的数据库表字段
- (void) initTableParamsDictionary:(SunbeamDBInitStatus) dbInitStatus
{
    if (dbInitStatus == SunbeamDBInitStatusFirst) {
        // 首次初始化数据库
        self.addTableParamsDictionary = self.currentDBTableDictionary;
        self.deleteTableParamsDictionary = nil;
        self.originTableParamsDictionary = nil;
        self.dropTableArray = nil;
    } else if (dbInitStatus == SunbeamDBInitStatusUpgrade) {
        // 升级数据库
        NSMutableArray* lastTableNameArray = [NSMutableArray arrayWithArray:[self.lastDBTableDictionary allKeys]];
        
        NSMutableArray* currentTableNameArray = [NSMutableArray arrayWithArray:[self.currentDBTableDictionary allKeys]];
        
        for (NSString* currentTableName in currentTableNameArray) {
            if ([lastTableNameArray containsObject:currentTableName]) {
                // 需要更新升级的数据库表
                [self initTableParamsIntoDict:currentTableName lastTableParamsArray:[self.lastDBTableDictionary objectForKey:currentTableName] currentTableParamsArray:[self.currentDBTableDictionary objectForKey:currentTableName]];
                
                [self.originTableArray addObject:currentTableName];
            } else {
                // 新添加的数据库表,不用管
                [self.addTableArray addObject:currentTableName];
            }
            
            [lastTableNameArray removeObject:currentTableName];
        }
        
        // 需要删除的数据库表
        self.dropTableArray = lastTableNameArray;
    }
}

- (void) initTableParamsIntoDict:(NSString *) tableName lastTableParamsArray:(NSMutableArray *) lastTableParamsArray currentTableParamsArray:(NSMutableArray *) currentTableParamsArray
{
    NSMutableArray* originParamsArray = [[NSMutableArray alloc] init];
    
    NSMutableArray* addParamsArray = [[NSMutableArray alloc] init];
    
    NSMutableArray* deleteParamsArray = nil;
    
    for (NSString* currentParam in currentTableParamsArray) {
        if ([lastTableParamsArray containsObject:currentParam]) {
            // 原有的
            [originParamsArray addObject:currentParam];
        } else {
            // 添加的
            [addParamsArray addObject:currentParam];
        }
        
        [lastTableParamsArray removeObject:currentParam];
    }
    
    // 删除的
    deleteParamsArray = lastTableParamsArray;
    
    [self.originTableParamsDictionary setObject:originParamsArray forKey:tableName];
    
    [self.addTableParamsDictionary setObject:addParamsArray forKey:tableName];
    
    [self.deleteTableParamsDictionary setObject:deleteParamsArray forKey:tableName];
}

#pragma mark - execute db migration
- (void) executeDBMigration
{
    if (self.dbInitStatus == SunbeamDBInitStatusFirst) {
        // 数据库表初次初始化
        // 根据currentDBTableDictionary初始化所有表格
        NSArray* tableInitNameArray = [self.currentDBTableDictionary allKeys];
        
        for (NSString* tbName in tableInitNameArray) {
            if (![self executeMigrationSQLCommand:[self formatTableCreateSQLCommand:tbName params:[self.currentDBTableDictionary objectForKey:tbName]]]) {
                @throw [NSException exceptionWithName:SunbeamDBMigrationExceptionName reason:@"DB Table create failed." userInfo:nil];
            }
        }
    } else if (self.dbInitStatus == SunbeamDBInitStatusUpgrade) {
        // 数据库表升级
        // 根据dropTableArray删除table
        for (NSString* dropTBName in self.dropTableArray) {
            if (![self executeMigrationSQLCommand:[self formatTableDropSQLCommand:dropTBName]]) {
                @throw [NSException exceptionWithName:SunbeamDBMigrationExceptionName reason:@"DB Table drop failed." userInfo:nil];
            }
        }
        
        // 根据originTableArray升级table
        // 将所有原有的table修改名称为 temp_"tableName"
        for (NSString* tbName in self.originTableArray) {
            if (![self executeMigrationSQLCommand:[self formatTableRenameSQLCommand:tbName]]) {
                @throw [NSException exceptionWithName:SunbeamDBMigrationExceptionName reason:@"DB Table rename failed." userInfo:nil];
            }
        }
        
        // 创建新的table
        NSArray* tableInitNameArray = [self.currentDBTableDictionary allKeys];
        
        for (NSString* tbName in tableInitNameArray) {
            if (![self executeMigrationSQLCommand:[self formatTableCreateSQLCommand:tbName params:[self.currentDBTableDictionary objectForKey:tbName]]]) {
                @throw [NSException exceptionWithName:SunbeamDBMigrationExceptionName reason:@"DB Table create failed." userInfo:nil];
            }
        }
        
        // 1、originTableParamsDictionary
        // 2、addTableParamsDictionary
        // 3、deleteTableParamsDictionary
        // 迁移数据
        NSArray* originTableNameArray = [self.originTableParamsDictionary allKeys];
        
        for (NSString* tbName in originTableNameArray) {
            if (![self executeMigrationSQLCommand:[self formatTableDataMigrationSQLCommand:tbName originTableParams:[self.originTableParamsDictionary objectForKey:tbName]]]) {
                @throw [NSException exceptionWithName:SunbeamDBMigrationExceptionName reason:@"DB Table data migration failed." userInfo:nil];
            } else {
                // 迁移数据成功后删除tempTables
                [self executeMigrationSQLCommand:[self formatTempTableDropSQLCommand:tbName]];
            }
        }
    }
}

/**
 *  格式化数据库表创建SQL语句
 */
- (NSString *) formatTableCreateSQLCommand:(NSString *) tableName params:(NSArray *) params
{
    NSMutableString* sqlString = [[NSMutableString alloc] init];
    
    for (int i=0; i<[params count]; i++) {
        if (i == [params count] - 1) {
            [sqlString appendFormat:@"'%@' VARCHAR(80)", params[i]];
        } else {
            [sqlString appendFormat:@"'%@' VARCHAR(80),", params[i]];
        }
    }
    
    return [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS '%@' ('id' INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,%@)", tableName, sqlString];
}

/**
 *  格式化数据库表删除语句
 */
- (NSString *) formatTableDropSQLCommand:(NSString *) tableName
{
    return [NSString stringWithFormat:@"DROP TABLE '%@'", tableName];
}

/**
 *  数据库表重命名
 */
- (NSString *) formatTableRenameSQLCommand:(NSString *) tableName
{
    NSString* tempTableName = [NSString stringWithFormat:@"temp_%@", tableName];
    
    return [NSString stringWithFormat:@"ALTER TABLE %@ RENAME TO %@", tableName, tempTableName];
}

/**
 *  数据库原始数据迁移操作
 */
- (NSString *) formatTableDataMigrationSQLCommand:(NSString *) tableName originTableParams:(NSArray *) originTableParams
{
    NSString* tempTableName = [NSString stringWithFormat:@"temp_%@", tableName];
    
    NSMutableString* sqlString = [[NSMutableString alloc] init];
    
    for (int i=0; i<[originTableParams count]; i++) {
        if (i == [originTableParams count] - 1) {
            [sqlString appendString:originTableParams[i]];
        } else {
            [sqlString appendFormat:@"%@,", originTableParams[i]];
        }
    }
    
    return [NSString stringWithFormat:@"INSERT INTO '%@' (%@) SELECT %@ FROM '%@'", tableName, sqlString, sqlString, tempTableName];
}

/**
 *  数据库数据迁移成功后，删除临时的数据库表
 */
- (NSString *) formatTempTableDropSQLCommand:(NSString *) tableName
{
    NSString* tempTableName = [NSString stringWithFormat:@"temp_%@", tableName];
    
    return [NSString stringWithFormat:@"DROP TABLE IF EXISTS '%@'", tempTableName];
}

/**
 *  执行数据库迁移相关sql命令
 */
- (BOOL) executeMigrationSQLCommand:(NSString *) sqlCommand
{
    if ([[SunbeamDBService sharedSunbeamDBService] executeTransactionSunbeamDBUpdate:sqlCommand]) {
        return YES;
    }
    
    return NO;
}

#pragma mark - complete db migration
- (void) completeDBMigration
{
    if (![self.delegate respondsToSelector:@selector(completeDBMigration)]) {
        @throw [NSException exceptionWithName:SunbeamDBMigrationExceptionName reason:@"SBFMDBMigration completeDBMigration should not be nil if you want to do migration." userInfo:nil];
        return;
    }
    
    self.dbMigrationStatus = SunbeamDBMigrationStatusSuccess;
    
    // 将当前sql脚本的版本存入数据库
    [self executeDBVersionUpdate];
    
    /**
     *  数据库升级操作成功，执行回调
     */
    [self.delegate completeDBMigration];
}

/**
 *  数据库升级成功后，更新当前数据库sql version
 */
- (BOOL) executeDBVersionUpdate
{
    if ([[SunbeamDBService sharedSunbeamDBService] executeTransactionSunbeamDBUpdate:UPDATE_SQL_VERSION_BY_SQL_FLAG, self.currentSQLVersion, SQL_TABLE_SQL_FLAG_COLUMN_VALUE]) {
        return YES;
    }
    
    return NO;
}

#pragma mark - private method

- (NSMutableDictionary *)lastDBTableDictionary
{
    if (_lastDBTableDictionary == nil) {
        _lastDBTableDictionary = [[NSMutableDictionary alloc] init];
    }
    
    return _lastDBTableDictionary;
}

- (NSMutableDictionary *)currentDBTableDictionary
{
    if (_currentDBTableDictionary == nil) {
        _currentDBTableDictionary = [[NSMutableDictionary alloc] init];
    }
    
    return _currentDBTableDictionary;
}

- (NSMutableDictionary *)addTableParamsDictionary
{
    if (_addTableParamsDictionary == nil) {
        _addTableParamsDictionary = [[NSMutableDictionary alloc] init];
    }
    
    return _addTableParamsDictionary;
}

- (NSMutableDictionary *)deleteTableParamsDictionary
{
    if (_deleteTableParamsDictionary == nil) {
        _deleteTableParamsDictionary = [[NSMutableDictionary alloc] init];
    }
    
    return _deleteTableParamsDictionary;
}

- (NSMutableDictionary *)originTableParamsDictionary
{
    if (_originTableParamsDictionary == nil) {
        _originTableParamsDictionary = [[NSMutableDictionary alloc] init];
    }
    
    return _originTableParamsDictionary;
}

- (NSMutableArray *)originTableArray
{
    if (_originTableArray == nil) {
        _originTableArray = [[NSMutableArray alloc] init];
    }
    
    return _originTableArray;
}

- (NSMutableArray *)addTableArray
{
    if (_addTableArray == nil) {
        _addTableArray = [[NSMutableArray alloc] init];
    }
    
    return _addTableArray;
}

- (NSMutableArray *)dropTableArray
{
    if (_dropTableArray == nil) {
        _dropTableArray = [[NSMutableArray alloc] init];
    }
    
    return _dropTableArray;
}

@end
