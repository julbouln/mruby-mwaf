MRuby::Gem::Specification.new('mruby-mwaf') do |spec|
  spec.author = "Julien Boulnois"
  spec.version = "0.0.1"
  spec.license = "MIT"

  spec.add_dependency "mruby-erb", :github => 'fukaoi/mruby-erb'
  spec.add_dependency "mruby-sqlite", :github => 'asfluido/mruby-sqlite'

end
