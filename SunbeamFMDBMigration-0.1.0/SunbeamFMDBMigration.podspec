Pod::Spec.new do |s|
  s.name = 'SunbeamFMDBMigration'
  s.version = '0.1.0'
  s.summary = 'SunbeamFMDBMigration -> an database migration strategy when app upgrade.'
  s.license = {"type"=>"MIT", "file"=>"LICENSE"}
  s.authors = {"chenxun"=>"chenxun1990@126.com"}
  s.homepage = 'https://github.com/sunbeamChen/SunbeamFMDBMigration'
  s.description = 'SunbeamFMDBMigration : when app upgrating, the database structure of new version may be different from the old version, then we should save the old version data into new version to ensure that user who use the app feel nothing after they upgrade their app to the newest version. This lib support table property add、delete.'
  s.requires_arc = true
  s.source = { :path => '.' }

  s.ios.deployment_target    = '7.0'
  s.ios.preserve_paths       = 'ios/SunbeamFMDBMigration.framework'
  s.ios.public_header_files  = 'ios/SunbeamFMDBMigration.framework/Versions/A/Headers/*.h'
  s.ios.resource             = 'ios/SunbeamFMDBMigration.framework/Versions/A/Resources/**/*'
  s.ios.vendored_frameworks  = 'ios/SunbeamFMDBMigration.framework'
end
