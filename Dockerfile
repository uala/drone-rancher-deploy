FROM bjm904/rancher-cli-k8s:v2.0.4 AS ranchercli

FROM ruby:2.6.2

COPY --from=ranchercli /usr/local/bin/kubectl /usr/local/bin
COPY --from=ranchercli /usr/bin/rancher /usr/local/bin

# Install rugged dependencies
RUN apt-get update -qq \
    && apt-get install cmake zlib1g zlib1g-dev libssh2-1-dev -y \
    && rm -rf /var/lib/apt/lists/*

RUN gem install bundler -v 1.17.2

ENV GEM_HOME="/usr/local/bundle"
ENV PATH $GEM_HOME/bin:$GEM_HOME/gems/bin:$PATH

WORKDIR /plugin
# Files that will change bundle dependencies
ADD Gemfile* *.gemspec /plugin/
ADD lib/rancher_deployer/version.rb /plugin/lib/rancher_deployer/
# Fix used Gemfile for plugin execution
RUN bundle install
# Add the whole plugin
ADD . /plugin
# Install built gem locally
RUN bundle exec rake install
# By default execute plugin code
CMD 'rancher-deployer'
