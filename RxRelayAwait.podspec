Pod::Spec.new do |s|
  s.name             = "RxRelayAwait"
  s.version          = "0.0.1"
  s.summary          = "Relays for RxSwift - PublishRelay, BehaviorRelay and ReplayRelay"
  s.description      = <<-DESC
Relays for RxSwiftAwait - PublishRelay, BehaviorRelay and ReplayRelay

* PublishRelay
* BehaviorRelay
* ReplayRelay
* Binding overloads
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

  s.ios.deployment_target = '9.0'
  # s.osx.deployment_target = '10.10'
  # s.watchos.deployment_target = '3.0'
  # s.tvos.deployment_target = '9.0'

  s.source_files          = 'RxRelay/**/*.{swift,h,m}'

  s.dependency 'RxSwiftAwait', '6.7.1'
  s.swift_version = '5.1'

  s.pod_target_xcconfig = { 'APPLICATION_EXTENSION_API_ONLY' => 'YES' }
end
