//
//  SunbeamSingletonService.h
//  Pods
//
//  Created by sunbeam on 16/6/21.
//
//

#ifndef SunbeamSingletonService_h
#define SunbeamSingletonService_h

#pragma mark - .h定义
// 由于宏定义里有需要替换的内容所以定义一个变量className
// ##用于分割、连接字符串
#define sunbeam_singleton_interface(className) +(className *)shared##className;

#pragma mark - .m实现
// \在代码中用于连接宏定义,以实现多行定义
#define sunbeam_singleton_implementation(className)\
+(className *)shared##className {\
static className *sharedInstance = nil;\
static dispatch_once_t once;\
dispatch_once(&once, ^{\
sharedInstance = [[self alloc] init];\
});\
return sharedInstance;\
}

#endif /* SunbeamSingletonService_h */
