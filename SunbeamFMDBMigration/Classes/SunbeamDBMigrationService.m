//
//  SunbeamDBMigrationService.m
//  Pods
//
//  Created by sunbeam on 16/6/21.
//
//

#import "SunbeamDBMigrationService.h"
#import "SunbeamDBService.h"

typedef NS_ENUM(NSInteger, SunbeamDBInitStatus) {
    SunbeamDBInitStatusFirst = 0, // DB初始化
    SunbeamDBInitStatusUpgrade = 1, // DB升级
    SunbeamDBInitStatusNoUpdate = 2, // DB没有更新
};

#define SunbeamDBMigrationErrorDomain @"SunbeamDBMigration_error_domain" // SBFMDBMigration error domain

// 默认sql bundle名称
#define SQL_BUNDLE_NAME_DEFAULT @"SunbeamDBMigrationSQL.bundle"
// tb_sql数据库迁移标识字段column value
#define SQL_TABLE_SQL_FLAG_COLUMN_VALUE @"sb_sql_flag"
// tb_sql数据库迁移标识字段column key
#define SQL_TABLE_SQL_VERSION_COLUMN_NAME @"sql_version"
// default sb_version
#define SB_VERSION_DEFAULT @"0"
// 查询tb_sql表是否存在
#define SELECT_SQL_TABLE_EXIST @"SELECT name FROM sqlite_master WHERE type='table' AND name='tb_sql';"
// tb_sql表创建sql语句
#define CREATE_SQL_TABLE @"CREATE TABLE IF NOT EXISTS 'tb_sql' ('sql_flag' VARCHAR(80), 'sql_version' VARCHAR(80));"
// tb_sql更新sql语句
#define UPDATE_SQL_VERSION_BY_SQL_FLAG @"UPDATE tb_sql SET sql_version=? WHERE sql_flag=?;"
// tb_sql查询sql语句
#define SELECT_SQL_VERSION_BY_SQL_FLAG @"SELECT sql_version FROM tb_sql WHERE sql_flag=?;"
// sql file name regex
static NSString *const SQLFilenameRegexString = @"^(\\d+)\\.sql$";

@interface SunbeamDBMigrationService()

@property (nonatomic, weak, readwrite) id<SunbeamDBMigrationDelegate> delegate;

@property (nonatomic, copy, readwrite) NSString* customSqlBundleName;

@property (nonatomic, copy) NSString* dbFilePath;

@property (nonatomic, copy) NSString* dbFileName;

@property (nonatomic, assign) SunbeamDBInitStatus dbInitStatus;

@end

@implementation SunbeamDBMigrationService

- (instancetype)initSunbeamDBMigrationService:(id<SunbeamDBMigrationDelegate>)delegate customSqlBundleName:(NSString *)customSqlBundleName dbFilePath:(NSString *)dbFilePath dbFileName:(NSString *)dbFileName
{
    if (self = [super init]) {
        self.delegate = delegate;
        self.customSqlBundleName = customSqlBundleName;
        self.dbFilePath = dbFilePath;
        self.dbFileName = dbFileName;
        NSLog(@"sunbeam FMDB migration service version is %@", SUNBEAM_DB_MIGRATION_SERVICE_VERSION);
    }
    
    return self;
}

- (NSError *)doSunbeamDBMigration
{
    if (self.delegate == nil) {
        return [NSError errorWithDomain:SunbeamDBMigrationErrorDomain code:SUNBEAM_DB_MIGRATION_ERROR_DELEGATE_IS_NIL userInfo:@{NSLocalizedDescriptionKey:@"db migration service delegate is nil"}];
    }
    
    if (self.customSqlBundleName == nil || [@"" isEqualToString:self.customSqlBundleName]) {
        self.customSqlBundleName = SQL_BUNDLE_NAME_DEFAULT;
    }
    
    NSError* error = nil;
    error = [[SunbeamDBService sharedSunbeamDBService] createFMDBService:self.dbFilePath dbFileName:self.dbFileName useDatabaseQueue:YES];
    if (error) {
        return error;
    }
    
    if ([self.delegate respondsToSelector:@selector(prepareDBMigration:)]) {
        error = [self.delegate prepareDBMigration:self];
    } else {
        error = [self prepareDBMigration];
    }
    if (error) {
        return error;
    }
    
    if ([self.delegate respondsToSelector:@selector(executeDBMigration:)]) {
        error = [self.delegate executeDBMigration:self];
    } else {
        error = [self executeDBMigration];
    }
    if (error) {
        return error;
    }
    
    if ([self.delegate respondsToSelector:@selector(completeDBMigration:)]) {
        error = [self.delegate completeDBMigration:self];
    } else {
        error = [self completeDBMigration];
    }
    
    return error;
}

#pragma mark - prepare db migration
- (NSError *) prepareDBMigration
{
    NSError* error = nil;
    
    // 初始化 lastSQLVersion
    if (self.lastSQLVersion == nil) {
        error = [self getLastSQLVersion];
    }
    if (error) {
        return error;
    }
    
    // 初始化currentSQLVersion、lastDBTableDictionary、currentDBTableDictionary
    error = [self getDBTableDictionary];
    if (error) {
        return error;
    }
    
    // 初始化 originTableParamsDictionary、addTableParamsDictionary、deleteTableParamsDictionary、originTableArray、addTableArray、dropTableArray
    return [self getTableParamsDictionary:self.dbInitStatus];
}

/**
 *  初始化lastSQLVersion
 */
- (NSError *) getLastSQLVersion
{
    NSError* error = nil;
    
    if ([self checkSQLTableExist]) {
        // 表存在，表示当前数据库处于待升级状态
        self.dbInitStatus = SunbeamDBInitStatusUpgrade;
        // 初始化lastSQLVersion
        self.lastSQLVersion = [self selectLastSQLVersionFromSQLTable];
        if (self.lastSQLVersion == nil) {
            error = [NSError errorWithDomain:SunbeamDBMigrationErrorDomain code:SUNBEAM_DB_MIGRATION_ERROR_TABLE_TB_SQL_COLUMN_SQL_VERSION_IS_NIL userInfo:@{NSLocalizedDescriptionKey:@"last sql version should not be nil while table tb_sql is exist"}];
        }
    } else {
        // 表不存在，表示当前数据库处于初始化状态
        self.dbInitStatus = SunbeamDBInitStatusFirst;
        // 初始化lastSQLVersion
        self.lastSQLVersion = SB_VERSION_DEFAULT;
        // 创建tb_sql，插入初始化数据值sql_version
        NSString* insertSql = [NSString stringWithFormat:@"INSERT INTO tb_sql (sql_flag,sql_version) VALUES ('%@','%@');", SQL_TABLE_SQL_FLAG_COLUMN_VALUE, self.lastSQLVersion];
        NSString* sqlStatements = [NSString stringWithFormat:@"%@\n%@", CREATE_SQL_TABLE, insertSql];
        NSLog(@"tb_sql表不存在:\n%@", sqlStatements);
        if (![[SunbeamDBService sharedSunbeamDBService] executeTransactionSunbeamDBStatements:sqlStatements]) {
            error = [NSError errorWithDomain:SunbeamDBMigrationErrorDomain code:SUNBEAM_DB_MIGRATION_ERROR_TABLE_TB_SQL_INIT_FAILED userInfo:@{NSLocalizedDescriptionKey:@"table tb_sql init failed"}];
        }
    }
    
    return error;
}

/**
 *  检查tb_sql表是否存在
 */
- (BOOL) checkSQLTableExist
{
    @try {
        NSMutableArray* array = [[SunbeamDBService sharedSunbeamDBService] executeSunbeamDBQuery:SELECT_SQL_TABLE_EXIST];
        if (array != nil && [array count] > 0) {
            return YES;
        }
        return NO;
    } @catch (NSException *exception) {
        return NO;
    }
}

/**
 *  tb_sql表中查询lastSQLVersion
 */
- (NSString *) selectLastSQLVersionFromSQLTable
{
    @try {
        NSMutableArray* array = [[SunbeamDBService sharedSunbeamDBService] executeSunbeamDBQuery:SELECT_SQL_VERSION_BY_SQL_FLAG, SQL_TABLE_SQL_FLAG_COLUMN_VALUE];
        if ([array count] != 1) {
            return nil;
        }
        return [[array objectAtIndex:0] objectForKey:SQL_TABLE_SQL_VERSION_COLUMN_NAME];
    } @catch (NSException *exception) {
        return nil;
    }
}

/**
 *  初始化bundle文件，lastDBTableDictionary & currentDBTableDictionary
 */
- (NSError *) getDBTableDictionary
{
    NSString* sqlFilePath = [[NSBundle mainBundle] pathForResource:self.customSqlBundleName ofType:@""];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:sqlFilePath]) {
        return [NSError errorWithDomain:SunbeamDBMigrationErrorDomain code:SUNBEAM_DB_MIGRATION_ERROR_SQL_BUNDLE_FILE_IS_NOT_EXIST userInfo:@{NSLocalizedDescriptionKey:@"sql bundle file is not exist"}];
    }
    
    NSMutableArray* sqlNameKeyArray = [[NSMutableArray alloc] init];
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
        return [NSError errorWithDomain:SunbeamDBMigrationErrorDomain code:SUNBEAM_DB_MIGRATION_ERROR_SQL_FILE_IN_BUNDLE_IS_NIL userInfo:@{NSLocalizedDescriptionKey:@"sql file in bundle is nil"}];
    }
    // sqlNameKeyArray排序
    NSArray* sqlNameKeySortedArray = [sqlNameKeyArray sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    // 初始化 currentSQLVersion
    self.currentSQLVersion = [sqlNameKeySortedArray lastObject];
    if ([self.currentSQLVersion integerValue] <= [self.lastSQLVersion integerValue]) {
        // 当前解析版本小于上次升级版本，表示本次APP数据库不需要升级，直接返回
        self.dbInitStatus = SunbeamDBInitStatusNoUpdate;
        return nil;
    }
    
    // 初始化 lastDBTableDictionary
    if (self.dbInitStatus == SunbeamDBInitStatusFirst) {
        self.lastDBTableDictionary = nil;
    } else {
        [self initDBTableDictionary:self.lastDBTableDictionary sqlFilePath:sqlFilePath sqlFileName:self.lastSQLVersion];
    }
    
    // 初始化 currentDBTableDictionary
    [self initDBTableDictionary:self.currentDBTableDictionary sqlFilePath:sqlFilePath sqlFileName:self.currentSQLVersion];
    
    return nil;
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
        NSMutableArray* tableStringArray = [NSMutableArray arrayWithArray:[trimmedCommand componentsSeparatedByString:@"|"]];
        NSString* key = [tableStringArray objectAtIndex:0];
        [tableStringArray removeObjectAtIndex:0];
        [dbTableInitDict setObject:tableStringArray forKey:key];
    }
}

// 初始化对应数据库表增加、删除的数据库表字段
- (NSError *) getTableParamsDictionary:(SunbeamDBInitStatus) dbInitStatus
{
    if (dbInitStatus == SunbeamDBInitStatusFirst) {
        self.originTableParamsDictionary = nil;
        self.addTableParamsDictionary = self.currentDBTableDictionary;
        self.deleteTableParamsDictionary = nil;
        self.originTableArray = nil;
        self.addTableArray = nil;
        self.dropTableArray = nil;
    } else if (dbInitStatus == SunbeamDBInitStatusUpgrade) {
        NSMutableArray* lastTableNameArray = [NSMutableArray arrayWithArray:[self.lastDBTableDictionary allKeys]];
        NSMutableArray* currentTableNameArray = [NSMutableArray arrayWithArray:[self.currentDBTableDictionary allKeys]];
        
        for (NSString* currentTableName in currentTableNameArray) {
            if ([lastTableNameArray containsObject:currentTableName]) {
                // 需要更新升级的数据库表
                [self initTableParamsIntoDict:currentTableName lastTableParamsArray:[self.lastDBTableDictionary objectForKey:currentTableName] currentTableParamsArray:[self.currentDBTableDictionary objectForKey:currentTableName]];
                [self.originTableArray addObject:currentTableName];
            } else {
                // 新添加的数据库表
                [self.addTableArray addObject:currentTableName];
            }
            [lastTableNameArray removeObject:currentTableName];
        }
        // 需要删除的数据库表
        self.dropTableArray = lastTableNameArray;
    }
    
    return nil;
}

- (void) initTableParamsIntoDict:(NSString *) tableName lastTableParamsArray:(NSMutableArray *) lastTableParamsArray currentTableParamsArray:(NSMutableArray *) currentTableParamsArray
{
    NSMutableArray* tempLastTableParamsArray = [NSMutableArray arrayWithArray:lastTableParamsArray];
    NSMutableArray* originParamsArray = [[NSMutableArray alloc] init];
    NSMutableArray* addParamsArray = [[NSMutableArray alloc] init];
    NSMutableArray* deleteParamsArray = nil;
    
    for (NSString* currentParam in currentTableParamsArray) {
        if ([tempLastTableParamsArray containsObject:currentParam]) {
            // 原有的
            [originParamsArray addObject:currentParam];
        } else {
            // 添加的
            [addParamsArray addObject:currentParam];
        }
        
        [tempLastTableParamsArray removeObject:currentParam];
    }
    // 删除的
    deleteParamsArray = tempLastTableParamsArray;
    
    [self.originTableParamsDictionary setObject:originParamsArray forKey:tableName];
    [self.addTableParamsDictionary setObject:addParamsArray forKey:tableName];
    [self.deleteTableParamsDictionary setObject:deleteParamsArray forKey:tableName];
}

#pragma mark - execute db migration
- (NSError *) executeDBMigration
{
    if (self.dbInitStatus == SunbeamDBInitStatusFirst) {
        // 数据库表初次初始化
        // 根据currentDBTableDictionary初始化所有表格
        NSMutableString* sqlStatements = [NSMutableString stringWithString:@""];
        
        NSArray* tableInitNameArray = [self.currentDBTableDictionary allKeys];
        for (NSString* tbName in tableInitNameArray) {
            [sqlStatements appendString:[self formatTableCreateSQLCommand:tbName params:[self.currentDBTableDictionary objectForKey:tbName]]];
        }
        NSLog(@"SunbeamDBInitStatusFirst:\n%@", sqlStatements);
        
        if (![[SunbeamDBService sharedSunbeamDBService] executeTransactionSunbeamDBStatements:sqlStatements]) {
            return [NSError errorWithDomain:SunbeamDBMigrationErrorDomain code:SUNBEAM_DB_MIGRATION_ERROR_DB_INIT_FAILED userInfo:@{NSLocalizedDescriptionKey:@"db first init failed"}];
        }
    } else if (self.dbInitStatus == SunbeamDBInitStatusUpgrade) {
        // 数据库表升级
        NSMutableString* sqlStatements = [NSMutableString stringWithString:@""];
        
        // 清理表名为temp_"tableName"的表格(防止脏数据)
        for (NSString* tbName in self.originTableArray) {
            [sqlStatements appendString:[self formatTempTableDropSQLCommand:tbName]];
        }
        // dropTableArray删除表格
        for (NSString* dropTBName in self.dropTableArray) {
            [sqlStatements appendString:[self formatTableDropSQLCommand:dropTBName]];
        }
        // originTableArray修改表名为temp_"tableName"
        for (NSString* tbName in self.originTableArray) {
            [sqlStatements appendString:[self formatTableRenameSQLCommand:tbName]];
        }
        // currentDBTableDictionary创建新表格
        NSArray* tableInitNameArray = [self.currentDBTableDictionary allKeys];
        for (NSString* tbName in tableInitNameArray) {
            [sqlStatements appendString:[self formatTableCreateSQLCommand:tbName params:[self.currentDBTableDictionary objectForKey:tbName]]];
        }
        // originTableParamsDictionary迁移数据
        NSArray* originTableNameArray = [self.originTableParamsDictionary allKeys];
        for (NSString* tbName in originTableNameArray) {
            [sqlStatements appendString:[self formatTableDataMigrationSQLCommand:tbName originTableParams:[self.originTableParamsDictionary objectForKey:tbName]]];
            [sqlStatements appendString:[self formatTempTableDropSQLCommand:tbName]];
        }
        NSLog(@"SunbeamDBInitStatusUpgrade:\n%@", sqlStatements);
        
        if (![[SunbeamDBService sharedSunbeamDBService] executeTransactionSunbeamDBStatements:sqlStatements]) {
            return [NSError errorWithDomain:SunbeamDBMigrationErrorDomain code:SUNBEAM_DB_MIGRATION_ERROR_DB_MIGRATION_FAILED userInfo:@{NSLocalizedDescriptionKey:@"db migration failed"}];
        }
    }
    
    return nil;
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
    
    return [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS '%@' ('id' INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,%@);\n", tableName, sqlString];
}

/**
 *  格式化数据库表删除语句
 */
- (NSString *) formatTableDropSQLCommand:(NSString *) tableName
{
    return [NSString stringWithFormat:@"DROP TABLE IF EXISTS '%@';\n", tableName];
}

/**
 *  数据库表重命名
 */
- (NSString *) formatTableRenameSQLCommand:(NSString *) tableName
{
    NSString* tempTableName = [NSString stringWithFormat:@"temp_%@", tableName];
    
    return [NSString stringWithFormat:@"ALTER TABLE %@ RENAME TO %@;\n", tableName, tempTableName];
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
    
    return [NSString stringWithFormat:@"INSERT INTO '%@' (%@) SELECT %@ FROM '%@';\n", tableName, sqlString, sqlString, tempTableName];
}

/**
 *  数据库数据迁移成功后，删除临时的数据库表
 */
- (NSString *) formatTempTableDropSQLCommand:(NSString *) tableName
{
    NSString* tempTableName = [NSString stringWithFormat:@"temp_%@", tableName];
    
    return [NSString stringWithFormat:@"DROP TABLE IF EXISTS '%@';\n", tempTableName];
}

#pragma mark - complete db migration
- (NSError *) completeDBMigration
{
    if (self.dbInitStatus == SunbeamDBInitStatusFirst || self.dbInitStatus == SunbeamDBInitStatusUpgrade) {
        // 将当前sql脚本的版本存入数据库
        if (![[SunbeamDBService sharedSunbeamDBService] executeTransactionSunbeamDBUpdate:UPDATE_SQL_VERSION_BY_SQL_FLAG, self.currentSQLVersion, SQL_TABLE_SQL_FLAG_COLUMN_VALUE]) {
            return [NSError errorWithDomain:SunbeamDBMigrationErrorDomain code:SUNBEAM_DB_MIGRATION_ERROR_TABLE_SQL_DATA_UPDATE_FAILED userInfo:@{NSLocalizedDescriptionKey:@"update sql version failed"}];
        }
    }
    
    return nil;
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

- (NSMutableDictionary *)originTableParamsDictionary
{
    if (_originTableParamsDictionary == nil) {
        _originTableParamsDictionary = [[NSMutableDictionary alloc] init];
    }
    
    return _originTableParamsDictionary;
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
