# Drone Rancher Deploy

This [drone plugin](https://drone.io/) can be used to deploy images on a Kubernetes cluster with Rancher 2.x.

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
* `server_url`: Your Rancher 2.x server url, mandatory
* `project`: Rancher project name, used for context switch
* `namespace`: Rancher namespace 
* `access_key`: Rancher access key used for authentication
* `secret_key`: Rancher secret key used for authentication
* `services`: YAML array of services to update in Rancher/K8S
* `image`: Docker image used to update services, if not given a name will be built from repo/branch/commit.
 
It's advised to customize image name. Remember: you can use ERB in YAML config, so you can set this to something like

```yaml
image: <%= "#{ENV['DRONE_REPO']}:ENV['DRONE_BRANCH']" %>
```

### Plugin settings

The plugin accepts the following settings:

* `config`: mandatory setting, a file path (relative to your repository root) containing environments configuration
* `dry_run`: setting this value to any non emmpty string will enable plugin dry-run mode, i.e. commands will printed to screen but they won't be executed 
* `colors`: can be used to disable colored output from executed commands. Default is true, setting it to `false` will disable colors.
* `logging`: logging level of plugin, default is `debug`, supported values: [any Ruby logger valid level](https://ruby-doc.org/stdlib-2.4.0/libdoc/logger/rdoc/Logger.html#class-Logger-label-Description)

