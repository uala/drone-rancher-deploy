FROM bjm904/rancher-cli-k8s:v2.0.4 AS ranchercli

FROM ruby:2.6.2

COPY --from=ranchercli /usr/local/bin/kubectl /usr/local/bin
COPY --from=ranchercli /usr/bin/rancher /usr/local/bin

RUN gem install bundler -v 1.17.2

ENV GEM_HOME="/usr/local/bundle"
ENV PATH $GEM_HOME/bin:$GEM_HOME/gems/bin:$PATH

WORKDIR /plugin
ADD Gemfile* /plugin/
# Fix used Gemfile for plugin execution
ENV BUNDLE_GEMFILE=/plugin/Gemfile
RUN bundle install

# Add plugin code
ADD deploy.rb /plugin/
# Default program
ENTRYPOINT /bin/bash -l -c 'bundle exec /plugin/deploy.rb'
