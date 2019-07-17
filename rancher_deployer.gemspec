lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "rancher_deployer/version"

Gem::Specification.new do |spec|
  spec.name    = "rancher_deployer"
  spec.version = RancherDeployer::VERSION
  spec.authors = ["Fabio Napoleoni"]
  spec.email   = ["f.napoleoni@gmail.com"]

  spec.summary     = %q{Deploy to a K8S cluster running with Rancher 2.x}
  spec.description = %q{Used as Drone plugin to deploy on K8S clusters during a drone build step}
  spec.homepage    = "https://github.com/uala/drone-rancher-deploy"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["homepage_uri"]    = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/uala/drone-rancher-deploy"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'tty-command'
  spec.add_runtime_dependency 'rugged'
  spec.add_runtime_dependency 'netrc'

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-doc"
  spec.add_development_dependency "awesome_print"
  spec.add_development_dependency "stub_env"
end
