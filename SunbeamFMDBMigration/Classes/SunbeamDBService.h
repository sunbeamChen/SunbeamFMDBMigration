//
//  SunbeamDBService.h
//  Pods
//
//  Created by sunbeam on 16/6/21.
//
//

#import <Foundation/Foundation.h>

#import "SunbeamSingletonService.h"

@interface SunbeamDBService : NSObject

/**
 *  单例
 */
sunbeam_singleton_interface(SunbeamDBService)

/**
 *  初始化SBFMDB服务
 *
 *  @param dbFilePath 数据库文件路径
 *  @param dbFileName 数据库文件名称
 */
- (void) initSunbeamDBService:(NSString *) dbFilePath dbFileName:(NSString *) dbFileName;

/**
 *  获取FMDBDatabase实例
 *
 *  @return FMDBDatabase
 */
- (id) getSunbeamFMDBDatabase;

/**
 *  执行sql语句更新命令
 *
 *  @param sql sql更新语句
 *
 *  @return 执行结果
 */
- (BOOL) executeTransactionSunbeamFMDBUpdate:(NSString*)sql, ...;

/**
 *  执行sql语句查询命令
 *
 *  @param sql sql查询语句
 *
 *  @return 查询结果
 */
- (NSMutableArray *) executeSunbeamFMDBQuery:(NSString*)sql, ...;

@end
