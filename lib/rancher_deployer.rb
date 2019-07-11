require 'rancher_deployer/version'
require 'yaml'
require 'erb'
require 'logger'

module RancherDeployer
  class Error < StandardError;
  end

  class Deployer
    attr_reader :logger

    def on_tag?
      !ENV['DRONE_TAG'].to_s.empty?
    end

  end
end
