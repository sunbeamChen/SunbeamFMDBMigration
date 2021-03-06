Pod::Spec.new do |s|
  s.name             = 'SunbeamFMDBMigration'    #名称
  s.version          = '0.1.14'  #版本号
  s.summary          = 'SunbeamFMDBMigration -> an database migration strategy when app upgrade.' #简短介绍，下面是详细介绍
  s.description      = <<-DESC
SunbeamFMDBMigration : when app upgrating, the database structure of new version may be different from the old version, then we should save the old version data into new version to ensure that user who use the app feel nothing after they upgrade their app to the newest version. This lib support table property add、delete.
                       DESC
  s.homepage         = 'https://github.com/sunbeamChen/SunbeamFMDBMigration'   #主页,这里要填写可以访问到的地址，不然验证不通过
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'    #截图
  s.license          = { :type => 'MIT', :file => 'LICENSE' }   #开源协议
  s.author           = { 'chenxun' => 'chenxun1990@126.com' }    #作者信息
  s.source           = { :git => 'https://github.com/sunbeamChen/SunbeamFMDBMigration.git', :tag => s.version.to_s }   #项目地址，这里不支持ssh的地址，验证不通过，只支持HTTP和HTTPS，最好使用HTTPS
  # s.social_media_url = 'http://sunbeamchen.github.io/'   #多媒体介绍地址

  s.ios.deployment_target = '7.0'   #支持的平台及版本

  s.requires_arc = true         #是否使用ARC，如果指定具体文件，则具体的问题使用ARC

  s.source_files = 'SunbeamFMDBMigration/Classes/*.{h,m}'   #代码源文件地址，**/*表示Classes目录及其子目录下所有文件，如果有多个目录下则用逗号分开，如果需要在项目中分组显示，这里也要做相应的设置

  # s.resource_bundles = {
  #   'SBFMDBMigration' => ['SunbeamFMDBMigration/Assets/*.png']
  # }   #资源文件地址

  s.public_header_files = 'SunbeamFMDBMigration/Classes/SunbeamFMDBMigration.h','SunbeamFMDBMigration/Classes/SunbeamDBMigrationService.h'    #公开头文件地址
  # s.frameworks = 'UIKit', 'MapKit'    #所需的framework，多个用逗号隔开
  s.dependency 'FMDB'   #依赖关系，该项目所依赖的其他库，如果有多个需要填写多个s.dependency
end
