Gem::Specification.new do |spec|
  spec.name = 'gdrive-cli'
  spec.version = '0.0.2'
  spec.license = 'MIT' # Just so gem build would shut up. Use it however you like.

  spec.summary = "Manage your Google Drive from command line"
  spec.author = "Jakub Šťastný"
  spec.homepage = 'https://github.com/jakub-stastny/gdrive-cli'

  spec.files = Dir["{lib,spec}/**/*.rb"] + Dir["bin/*"] + ['Gemfile', 'Gemfile.lock', 'README.md', 'gdrive-cli.gemspec']
  spec.executables << 'gdrive'
end
