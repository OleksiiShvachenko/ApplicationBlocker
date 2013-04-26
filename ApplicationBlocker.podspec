Pod::Spec.new do |s|
  s.name         = "ApplicationBlocker"
  s.version      = "0.0.2"
  s.summary      = "ApplicationBlocker use to block activity of application."
  s.homepage     = "https://github.com/shalex9154/ApplicationBlocker"
  s.license      = 'MIT'
  s.author       = { "Oleksii Shvachenko" => "alexey.shvachenko@gmail.com" }
  s.source       = { :git => "https://github.com/shalex9154/ApplicationBlocker.git", :tag => '0.0.2'}
  s.source_files = 'ApplicationBlocker.h'
  s.framework  = 'Security'
  s.requires_arc = false
end
