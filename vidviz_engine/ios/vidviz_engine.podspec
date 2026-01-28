Pod::Spec.new do |s|
  s.name             = 'vidviz_engine'
  s.version          = '0.0.1'
  s.summary          = 'VidViz Native Render Engine'
  s.description      = 'High-performance GPU-accelerated video export engine'
  s.homepage         = 'https://github.com/example/vidviz_engine'
  s.license          = { :type => 'MIT' }
  s.author           = { 'VidViz' => 'contact@vidviz.com' }
  s.source           = { :path => '.' }
  
  s.ios.deployment_target = '15.0'
  s.swift_version = '5.0'
  
  # Flutter dependency
  s.dependency 'Flutter'
  
  # Source files - Core C++
  s.source_files = 'Classes/**/*.{h,m,mm}'
  
  # Public headers
  s.public_header_files = 'Classes/**/*.h'
  
  # Frameworks
  s.frameworks = [
    'Metal',
    'MetalKit',
    'AVFoundation',
    'CoreVideo',
    'CoreMedia',
    'QuartzCore'
  ]
  
  # C++ settings
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) VIDVIZ_BUILDING_LIBRARY=1',
    'HEADER_SEARCH_PATHS' => '$(inherited) "$(PODS_TARGET_SRCROOT)/../native" "$(PODS_TARGET_SRCROOT)/../native/core" "$(PODS_TARGET_SRCROOT)/../native/common" "$(PODS_TARGET_SRCROOT)/../native/platform"',
    'STRIP_INSTALLED_PRODUCT' => 'NO',
    'GCC_SYMBOLS_PRIVATE_EXTERN' => 'NO',
    'ENABLE_BITCODE' => 'NO'
  }

  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -Wl,-u,_vidviz_engine_init -Wl,-u,_vidviz_engine_destroy -Wl,-u,_vidviz_submit_job -Wl,-u,_vidviz_cancel_job -Wl,-u,_vidviz_get_status -Wl,-u,_vidviz_get_last_init_error -Wl,-u,_vidviz_free_string'
  }

  s.libraries = 'c++'
end
