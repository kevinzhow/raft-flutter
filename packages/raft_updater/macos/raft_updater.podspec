# CocoaPods fallback for builds with Swift Package Manager disabled. Flutter
# prefers raft_updater/Package.swift when SPM is enabled (this app does).
Pod::Spec.new do |s|
  s.name             = 'raft_updater'
  s.version          = '0.1.0'
  s.summary          = 'Sparkle 2 updater bridge for Raft.'
  s.description      = 'Method-channel bridge to Sparkle 2 (SPUStandardUpdaterController).'
  s.homepage         = 'https://github.com/kevinzhow/raft-flutter'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Raft' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'raft_updater/Sources/raft_updater/**/*.swift'
  s.dependency 'FlutterMacOS'
  s.dependency 'Sparkle', '2.10.0'

  s.platform = :osx, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
