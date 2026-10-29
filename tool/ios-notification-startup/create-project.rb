# Standalone UI runner: no product target or signing settings are changed.
require 'xcodeproj'
require 'json'
require 'fileutils'
abort 'Usage: create-project.rb EXISTING_OUTPUT_DIR QA_BUNDLE_ID SIMULATOR_UDID allow|deny|audit' unless ARGV.length == 4
work = Pathname.new(ARGV.fetch(0)).realpath
bundle = ARGV.fetch(1)
simulator = ARGV.fetch(2)
choice = ARGV.fetch(3)
raise 'A simulator UDID is required' unless simulator.match?(/\A[0-9A-Fa-f-]{36}\z/)
raise 'Isolated QA identity required' unless bundle.start_with?('app.raft.notification-startup.qa.')
raise 'Expected allow, deny or audit' unless %w[allow deny audit].include?(choice)
FileUtils.cp(File.join(__dir__, 'NotificationStartupUITests.swift'), work)
File.write(work.join('Configuration.swift'), "enum Configuration { static let bundle = #{bundle.to_json}; static let simulator = #{simulator.to_json}; static let choice = #{choice.to_json} }\n")
project = Xcodeproj::Project.new(work.join('NotificationStartupUI.xcodeproj'))
target = project.new_target(:ui_test_bundle, 'NotificationStartupUITests', :ios, '17.0')
%w[NotificationStartupUITests.swift Configuration.swift].each do |name|
  target.source_build_phase.add_file_reference(project.main_group.new_file(name))
end
target.build_configurations.each do |config|
  config.build_settings.merge!({ 'SWIFT_VERSION' => '5.0', 'CODE_SIGNING_ALLOWED' => 'NO',
    'GENERATE_INFOPLIST_FILE' => 'YES', 'TARGETED_DEVICE_FAMILY' => '1,2',
    'PRODUCT_BUNDLE_IDENTIFIER' => 'app.raft.notification-startup.uitests' })
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.add_test_target(target)
scheme.save_as(project.path, 'NotificationStartupUI', true)
