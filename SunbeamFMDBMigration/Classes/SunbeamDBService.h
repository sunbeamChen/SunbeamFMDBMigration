//
//  SunbeamDBService.h
//  Pods
//
//  Created by sunbeam on 16/6/21.
//
//

#import <Foundation/Foundation.h>

@interface SunbeamDBService : NSObject

/**
 *  单例
 */
+ (SunbeamDBService *) sharedSunbeamDBService;

/**
 *  初始化SBFMDB服务
 *
 *  @param dbFilePath 数据库文件路径
 *  @param dbFileName 数据库文件名称
 *  @param useDatabaseQueue 是否使用database queue
 */
- (NSError *) createFMDBService:(NSString *) dbFilePath dbFileName:(NSString *) dbFileName useDatabaseQueue:(BOOL) useDatabaseQueue;

/**
 *  执行sql语句更新命令
 *
 *  @param sql sql更新语句
 *
 *  @return 执行结果
 */
- (BOOL) executeTransactionSunbeamDBUpdate:(NSString*)sql, ...;

/**
 *  执行sql语句查询命令
 *
 *  @param sql sql查询语句
 *
 *  @return 查询结果
 */
- (NSMutableArray *) executeSunbeamDBQuery:(NSString*)sql, ...;

@end
