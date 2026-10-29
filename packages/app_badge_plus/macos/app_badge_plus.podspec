require 'yaml'

pubspec = YAML.load_file(File.join('..', 'pubspec.yaml'))
library_version = pubspec['version'].gsub('+', '-')

Pod::Spec.new do |s|
  s.name             = 'app_badge_plus'
  s.version          = library_version
  s.summary          = 'App badge plugin for Flutter.'
  s.description      = <<-DESC
App badge plugin for Flutter, use this plugin to set the app badge number on macos.
                       DESC
  s.homepage         = 'https://github.com/windows7lake/app_badge_plus'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Lio lin' => 'windows7lake@gmail.com' }

  s.source           = { :http => 'https://github.com/windows7lake/app_badge_plus/tree/main/macos' }
  s.source_files = 'app_badge_plus/Source/app_badge_plus/**/*.{h,m,mm,swift}'

  s.resource_bundles = {'app_badge_plus_privacy' => ['app_badge_plus/Source/app_badge_plus/Resources/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
