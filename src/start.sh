#!/bin/bash

rm -f ./tmp/pids/server.pid

# Install node_modules if doesn't exist in container
if [ ! -d "node_modules" ]; then
    npm i
fi

#bundle install &&

yarn build && yarn build:css

if [ ! -f "config/sunspot.yml" ]; then
    rails generate sunspot_rails:install
fi

sed -i 's/exists/exist/g' /usr/local/bundle/gems/sunspot_solr-2.6.0/lib/sunspot/solr/server.rb
rm -rf ./solr/pids/development/sunspot-solr-development.pid

bundle exec rake sunspot:solr:run & ./bin/rails server -b "0.0.0.0" && fg 
