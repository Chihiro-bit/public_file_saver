#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint public_file_saver.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'public_file_saver'
  s.version          = '1.0.0'
  s.summary          = 'Cross-platform Flutter plugin to save files to publicly visible locations.'
  s.description      = <<-DESC
A cross-platform Flutter plugin to save files to publicly visible locations
(Downloads, Documents) on Android, iOS, macOS, Web, Windows, Linux, and HarmonyOS.
                       DESC
  s.homepage         = 'https://github.com/Chihiro-bit/public_file_saver'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Chihiro-bit' => 'noreply@github.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'public_file_saver/Sources/public_file_saver/**/*.swift'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
