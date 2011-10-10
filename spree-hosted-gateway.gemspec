Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'hosted_gateway'
<<<<<<< HEAD
  s.version     = '1.0.1'
=======
  s.version     = '1.0.5'
>>>>>>> ab56a8c81ebfbd6d8de931af123a7b823e7fb2f5
  s.summary     = 'A Spree extension adding support for an external payment gateway service (i.e. offsite payment)'
  #s.description = 'Add (optional) gem description here'
  s.required_ruby_version = '>= 1.8.7'

  s.author            = 'Josh McArthur, Karl Herler'
  #s.email             = 'david@loudthinking.com'
  s.homepage          = 'http://www.github.com/karlherler/'
  # s.rubyforge_project = 'actionmailer'

  s.files        = Dir['CHANGELOG', 'README.md', 'LICENSE', 'lib/**/*', 'app/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.has_rdoc = true

  s.add_dependency('spree_core', '>= 0.30.1')
  s.add_dependency('htmlentities')
  s.add_dependency('unicode')
end
