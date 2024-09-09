Pod::Spec.new do |s|
  s.name             = "RxSwiftAwait"
  s.version          = "0.0.1"
  s.summary          = "RxSwift is a Swift implementation of Reactive Extensions"
  s.description      = <<-DESC
  RxSwift except no locks, full structured concurrency
                        DESC
  s.homepage         = "https://github.com/isaac-weisberg/RxSwiftAwait"
  s.license          = 'MIT'
  s.author           = {
    "Krunoslav Zaher" => "krunoslav.zaher@gmail.com",
    'Shai "freak4pc" Mishali' => "freak4pc@gmail.com",
    'Isaac "The Dad" Weisberg' => "net.caroline.weisberg@gmail.com"
  }
  s.source           = { :git => "https://github.com/isaac-weisberg/RxSwiftAwait.git", :tag => s.version.to_s }

  s.requires_arc          = true

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  # s.watchos.deployment_target = '3.0'
  # s.tvos.deployment_target = '9.0'

  s.source_files          = 'RxSwift/**/*.swift', 'Platform/**/*.swift'
  s.exclude_files         = 'RxSwift/Platform/**/*.swift'

  s.swift_version = '5.1'

  s.pod_target_xcconfig = { 'APPLICATION_EXTENSION_API_ONLY' => 'YES' }
end
