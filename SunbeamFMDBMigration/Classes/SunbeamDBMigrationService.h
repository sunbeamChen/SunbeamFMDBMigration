//
//  SunbeamDBMigrationService.h
//  Pods
//
//  Created by sunbeam on 16/6/21.
//
//

#import <Foundation/Foundation.h>

/**
 *  SunbeamDBMigrationService lib version
 */
#define SUNBEAM_DB_MIGRATION_LIB_VERSION @"0.1.0"

/**
 *  SunbeamFMDBMigration运行结果
 */
typedef NS_ENUM(NSInteger, SunbeamDBMigrationStatus) {
    /**
     *  成功
     */
    SunbeamDBMigrationStatusFailed = 0,
    
    /**
     *  失败
     */
    SunbeamDBMigrationStatusSuccess = 1,
};

/**
 *  SunbeamFMDBMigration代理
 */
@protocol SunbeamDBMigrationDelegate <NSObject>

/**
 *  可选服务，如果没有实现该代理方法，将会按照默认的方式进行执行
 */
@optional
/**
 *  数据库迁移开始，主要用来进行相关的初始化操作
 */
- (void) prepareDBMigration;

/**
 *  数据库迁移执行，主要用来进行具体的数据库迁移操作
 */
- (void) executeDBMigration;

/**
 *  必须实现服务，如果没有实现该代理方法，将会抛出异常
 */
@required
/**
 *  数据库迁移完成，返回迁移的结果（出错后，会返回错误原因）
 */
- (void) completeDBMigration;

@end

@interface SunbeamDBMigrationService : NSObject

/**
 *  服务名称
 */
@property (nonatomic, copy, readonly) NSString* libName;

/**
 *  服务描述
 */
@property (nonatomic, copy, readonly) NSString* libDesc;

/**
 *  服务版本
 */
@property (nonatomic, copy, readonly) NSString* libVersion;

/**
 *  初始化数据库迁移服务
 *
 *  @param delegate            代理
 *  @param database            FMDB数据库实例
 *  @param customSqlBundleName 自定义sql bundle名称，如果为nil，则采用默认名称SBFMDBMigrationSQL
 *
 *  @return 返回数据库迁移服务实例
 */
- (instancetype) initSunbeamDBMigrationService:(id<SunbeamDBMigrationDelegate>) delegate customSqlBundleName:(NSString *) customSqlBundleName;

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
 *  上次升级数据库解析后的sql脚本保存的地址 {"tb_user":["userId","userName","userCellphone"],...}
 */
@property (nonatomic, strong) NSMutableDictionary* lastDBTableDictionary;

/**
 *  本次升级数据库解析后的sql脚本保存的地址 {"tb_user":["userId","userName","userSex","userAge"],...}
 */
@property (nonatomic, strong) NSMutableDictionary* currentDBTableDictionary;

/**
 *  原有的数据库表字段 {"tb_user":["userId","userName"]}
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
 *  原有的table ["tb_user",...]
 */
@property (nonatomic, strong) NSMutableArray* originTableArray;

/**
 *  添加的table ["tb_product",...]
 */
@property (nonatomic, strong) NSMutableArray* addTableArray;

/**
 *  删除的table ["tb_media",...]
 */
@property (nonatomic, strong) NSMutableArray* dropTableArray;

/**
 *  升级数据库结果
 */
@property (nonatomic, assign) SunbeamDBMigrationStatus dbMigrationStatus;

/**
 *  开始执行数据库迁移策略
 */
- (void) doSunbeamDBMigration;

@end
