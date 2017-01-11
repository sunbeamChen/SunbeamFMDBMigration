//
//  SunbeamDBMigrationService.h
//  Pods
//
//  Created by sunbeam on 16/6/21.
//
//

#import <Foundation/Foundation.h>

/**
 *  SunbeamDBMigrationService service version
 */
#define SUNBEAM_DB_MIGRATION_SERVICE_VERSION @"0.1.13"

typedef enum : NSUInteger {
    
    // db migration service delegate is nil
    SUNBEAM_DB_MIGRATION_ERROR_DELEGATE_IS_NIL = 10000,
    
    // last sql version should not be nil while table tb_sql is exist
    SUNBEAM_DB_MIGRATION_ERROR_TABLE_TB_SQL_COLUMN_SQL_VERSION_IS_NIL = SUNBEAM_DB_MIGRATION_ERROR_DELEGATE_IS_NIL + 1,
    
    // table tb_sql init failed
    SUNBEAM_DB_MIGRATION_ERROR_TABLE_TB_SQL_INIT_FAILED = SUNBEAM_DB_MIGRATION_ERROR_TABLE_TB_SQL_COLUMN_SQL_VERSION_IS_NIL + 1,
    
    // sql bundle file is not exist
    SUNBEAM_DB_MIGRATION_ERROR_SQL_BUNDLE_FILE_IS_NOT_EXIST = SUNBEAM_DB_MIGRATION_ERROR_TABLE_TB_SQL_INIT_FAILED + 1,
    
    // sql file in bundle is nil
    SUNBEAM_DB_MIGRATION_ERROR_SQL_FILE_IN_BUNDLE_IS_NIL = SUNBEAM_DB_MIGRATION_ERROR_SQL_BUNDLE_FILE_IS_NOT_EXIST + 1,
    
    // db first init failed
    SUNBEAM_DB_MIGRATION_ERROR_DB_INIT_FAILED = SUNBEAM_DB_MIGRATION_ERROR_SQL_FILE_IN_BUNDLE_IS_NIL + 1,
    
    // db migration failed
    SUNBEAM_DB_MIGRATION_ERROR_DB_MIGRATION_FAILED = SUNBEAM_DB_MIGRATION_ERROR_DB_INIT_FAILED + 1,
    
    // update sql version failed
    SUNBEAM_DB_MIGRATION_ERROR_TABLE_SQL_DATA_UPDATE_FAILED = SUNBEAM_DB_MIGRATION_ERROR_DB_MIGRATION_FAILED + 1,
    
} SUNBEAM_DB_MIGRATION_ERROR;

@class SunbeamDBMigrationService;

/**
 *  SunbeamFMDBMigration代理
 */
@protocol SunbeamDBMigrationDelegate <NSObject>

/**
 *  可选服务，如果没有实现该代理方法，将会按照默认的方式执行
 */
@optional
/**
 数据库迁移开始，主要用来进行相关的初始化操作
 即初始化 lastSQLVersion、currentSQLVersion、lastDBTableDictionary、currentDBTableDictionary、originTableParamsDictionary、addTableParamsDictionary、deleteTableParamsDictionary、originTableArray、addTableArray、dropTableArray这十个对象，用户可以按照自己的规则进行保存和处理

 @return NSError
 */
- (NSError *) prepareDBMigration:(SunbeamDBMigrationService *) migrationService;

/**
 数据库迁移执行，主要用来进行具体的数据库迁移操作
 即执行数据库相关表的增删、数据库表字段的相关增删、数据库表字段数据的迁移操作

 @return NSError
 */
- (NSError *) executeDBMigration:(SunbeamDBMigrationService *) migrationService;

/**
 数据库迁移完成后执行相关操作
 即按照用户自己的规则持久化lastSQLVersion等相关数据

 @return NSError
 */
- (NSError *) completeDBMigration:(SunbeamDBMigrationService *) migrationService;

@end

@interface SunbeamDBMigrationService : NSObject

/**
 *  初始化数据库迁移服务
 *
 *  @param delegate            代理
 *  @param database            FMDB数据库实例
 *  @param customSqlBundleName 自定义sql bundle名称，如果为nil，则采用默认名称SunbeamDBMigrationSQL
 *
 *  @return 返回数据库迁移服务实例
 */
- (instancetype) initSunbeamDBMigrationService:(id<SunbeamDBMigrationDelegate>) delegate customSqlBundleName:(NSString *) customSqlBundleName dbFilePath:(NSString *) dbFilePath dbFileName:(NSString *) dbFileName;

/**
 *  数据库迁移服务代理
 */
@property (nonatomic, weak, readonly) id<SunbeamDBMigrationDelegate> delegate;

/**
 *  自定义sql bundle名称
 */
@property (nonatomic, copy, readonly) NSString* customSqlBundleName;

/**
 *  上次数据库迁移成功后，保存的app build version，该参数用来标识是否需要进行数据库迁移操作
 *  默认app build version格式为：年月日版本号，eg:16061700、16061701
 *  默认保存在数据库db_version中，用户可以自定义保存在UserDefaults中，在prepareDBMigration中需要将该值取出并赋值给lastSQLVersion
 */
@property (nonatomic, copy) NSString* lastSQLVersion;

/**
 *  本次数据库升级成功后，保存的app build version，即sql脚本去除后缀的名称
 */
@property (nonatomic, copy) NSString* currentSQLVersion;

/**
 *  上次数据库升级后的sql脚本保存数据 {"tb_user":["userId","userName","userCellphone"],...}
 */
@property (nonatomic, strong) NSMutableDictionary* lastDBTableDictionary;

/**
 *  本次数据库升级后的sql脚本保存数据 {"tb_user":["userId","userName","userSex","userAge"],...}
 */
@property (nonatomic, strong) NSMutableDictionary* currentDBTableDictionary;

/**
 *  未发生变化的数据库表字段 {"tb_user":["userId","userName"]}
 */
@property (nonatomic, strong) NSMutableDictionary* originTableParamsDictionary;

/**
 *  增加的数据库表字段 {"tb_user":["userSex","userAge"]}
 */
@property (nonatomic, strong) NSMutableDictionary* addTableParamsDictionary;

/**
 *  删除的数据库表字段 {"tb_user":["userCellphone"]}
 */
@property (nonatomic, strong) NSMutableDictionary* deleteTableParamsDictionary;

/**
 *  未发生变化的的数据库表 ["tb_user",...]
 */
@property (nonatomic, strong) NSMutableArray* originTableArray;

/**
 *  增加的数据库表 ["tb_product",...]
 */
@property (nonatomic, strong) NSMutableArray* addTableArray;

/**
 *  删除的数据库表 ["tb_media",...]
 */
@property (nonatomic, strong) NSMutableArray* dropTableArray;

/**
 开始执行数据库迁移策略

 @return NSError
 */
- (NSError *) doSunbeamDBMigration;

@end
