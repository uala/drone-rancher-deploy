# Drone Rancher Deploy

[![Build Status](https://drone.uala.dev/api/badges/uala/drone-rancher-deploy/status.svg)](https://drone.uala.dev/uala/drone-rancher-deploy)

This [drone plugin](https://drone.io/) can be used to deploy images on a Kubernetes cluster with Rancher 2.x.

Plugin in action:

![Execution](/example.png)

## Usage

In order to use this plugin in one your Drone steps you can use the following step definition

```yaml
steps:
  - name: rancher-deploy
    image: uala/drone-rancher-deploy
    settings:
      config: k8s-envs.yml
      dry_run: true
    environment:
      RANCHER_ACCESS_KEY:
        from_secret: RANCHER_ACCESS_KEY
      RANCHER_SECRET_KEY:
        from_secret: RANCHER_SECRET_KEY
``` 

Plugin image will read the given config (in your repository) and deploy all matching confiugurations.

### Configuration file

Configuration file is a YAML (with ERB support) file stored in your repository and configured using plugin setting named `config`.

This file contains yaml definitions of services to update per Rancher Projects/Namespaces and credentials

```yaml
develop:
  branch: develop
  server_url: "https://k8s.example.com"
  project: RancherProject
  namespace: my-namespace
  access_key: <%= ENV['RANCHER_ACCESS_KEY'] %>
  secret_key: <%= ENV['RANCHER_SECRET_KEY'] %>
  services:
    - web
    - worker
    - cron
```

Any configuration name can be used, plugin will skip those starting with a `.` (dot) in order to allow usage of YAML references 
as in the following example:

```yaml
.common: &common
  branch: develop
  server_url: "https://k8s.example.com"
  project: RancherProject
  access_key: <%= ENV['RANCHER_ACCESS_KEY'] %>
  secret_key: <%= ENV['RANCHER_SECRET_KEY'] %>
  services:
    - web
    - worker
    - cron

develop:
  <<: *common
  namespace: develop

production:
  <<: *common
  namespace: production
```

#### Configuration file reference

* `branch`: This is the most important settings, it contains a branch name that plugin will use to determine wheter this
configuration must be deployed. It supports plain branch names and also a regexp (e.g. `feature/.*`). At 
 [DRONE_SOURCE_BRANCH](https://docs.drone.io/reference/environ/drone-source-branch/) will be used to match, in order
 to support both `push` and `pull_request` events in Drone.io.
* `only_tags`: if true this configuration will be executed if and only if current deploy is running on a tag
(n.b. it will **NOT** deploy even if branch regexp matches)
* `server_url`: Your Rancher 2.x server url, mandatory
* `project`: Rancher project name, used for context switch
* `namespace`: Rancher namespace 
* `access_key`: Rancher access key used for authentication
* `secret_key`: Rancher secret key used for authentication
* `services`: YAML array of services to update in Rancher/K8S
* `image`: Docker image used to update services, if not given a name will be built from repo/branch/commit.
* `login_options`: Additional `rancher login` options (e.g. `--skip-verify`)
* `kubectl_options`: optional, string, any additional flags to be passed to the kubectl command
 
It's advised to customize image name. Remember: you can use ERB in YAML config, so you can set this to something like

```yaml
image: <%= "#{ENV['DRONE_REPO']}:ENV['DRONE_BRANCH']" %>
```

### Tag check action

This plugin action is used to enforce that deployments of tags happens in a restricted branch.
To use this feature you should configure the plugin in the following way
 
```yaml
steps:
  - name: rancher-deploy
    image: uala/drone-rancher-deploy
    settings:
      action: tag_check
      enforce_branch_for_tag: <some-branch-name>
      enforce_head: true # Optional, default is false            
``` 

With this configuration plugin will check on what branches is the tag you're deploying
and fails if tag is not on the given branch. With optional `enforce_head` flag plugin
will also ensure that tag point to head of the given branch.

See integrations specs for this behavior.  

### Plugin settings

The plugin accepts the following settings:

* `config`: mandatory setting, a file path (relative to your repository root) containing environments configuration
* `dry_run`: setting this value to any non empty string will enable plugin dry-run mode, i.e. commands will printed to screen but they won't be executed 
* `colors`: can be used to disable colored output from executed commands. Default is true, setting it to `false` will disable colors.
* `logging`: logging level of plugin, default is `info`, supported values: [any Ruby logger valid level](https://ruby-doc.org/stdlib-2.4.0/libdoc/logger/rdoc/Logger.html#class-Logger-label-Description)
* `action`: action to use in plugin, one of `[deploy, tag_check]`
* `enforce_branch_for_tag`: string, a branch name, used in `tag_check` action
* `enforce_head`: boolean any non empty string will be considered as `true`, used in `tag_check` action 

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/uala/drone-rancher-deploy

## License

Drone Rancher Deploy is released under the [MIT License](https://opensource.org/licenses/MIT).

