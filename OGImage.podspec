Pod::Spec.new do |s|
  s.name         = "OGImage"
  s.version      = "0.0.5"
  s.summary      = "OGImage provides a simple abstraction for loading images from the network, processing them, and caching them locally."
  s.homepage     = "http://github.com/origamilabs/OGImage"
  s.license      = 'MIT'
  s.author       = { "Art Gillespie" => "art@origami.com" }
  s.source       = { :git => "https://github.com/sixten/OGImage.git", :branch => "develop" }
  s.platform     = :ios, '7.1'
  s.source_files = 'OGImage', 'OGImage/**/*.{h,m}'
  s.frameworks  = 'Accelerate', 'AssetsLibrary', 'ImageIO'
  s.requires_arc = true
end
