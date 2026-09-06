#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint public_file_saver.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'public_file_saver'
  s.version          = '1.2.0'
  s.summary          = 'Cross-platform Flutter plugin to save files to publicly visible locations.'
  s.description      = <<-DESC
A reliable Flutter plugin for saving files to user-visible locations
(Downloads, Documents) on Android, iOS, macOS, Web, Windows, Linux, and HarmonyOS.
                       DESC
  s.homepage         = 'https://github.com/Chihiro-bit/public_file_saver'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Chihiro-bit' => 'noreply@github.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'public_file_saver/Sources/public_file_saver/**/*.swift'
  s.resource_bundles = {'public_file_saver_privacy' => ['public_file_saver/Sources/public_file_saver/Resources/PrivacyInfo.xcprivacy']}
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
