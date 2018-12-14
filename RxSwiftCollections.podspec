Pod::Spec.new do |spec|
  spec.name             = 'RxSwiftCollections'
  spec.version          = '0.2.0'
  spec.summary          = 'Collections for handling ansynchronous streams with RxSwift.'

  spec.description      = <<-DESC
                       A suite of collections using RxSwift to make your life easier.
                       DESC

  spec.homepage         = 'https://github.com/mproberts/RxSwiftCollections'
  spec.license          = { :type => 'MIT', :file => 'LICENSE' }
  spec.author           = { 'Mike Roberts' => 'mike@mpr.io' }
  spec.source           = { :git => 'https://github.com/mproberts/RxSwiftCollections.git', :tag => spec.version.to_s }

  spec.source_files = 'RxSwiftCollections/Classes/*'

  spec.dependency 'RxSwift',    '~> 4.0'
  spec.dependency 'RxCocoa',    '~> 4.0'
  spec.dependency 'DeepDiff',   '~> 1.2'

  spec.default_subspec = 'iOS'

  spec.subspec 'macOS' do |macosspec|
      macosspec.osx.deployment_target = '10.14'
  end

  spec.subspec 'iOS' do |iosspec|
      iosspec.ios.deployment_target = '8.0'
      iosspec.source_files = 'RxSwiftCollections/Classes/**/*'
      iosspec.frameworks = 'UIKit'
      iosspec.dependency 'IGListKit',  '~> 3.4.0'
  end


end
