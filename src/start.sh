#!/bin/bash

rm -f ./tmp/pids/server.pid

bundle install

# Precompile assets
bundle exec rails assets:precompile

# Start Rails server
./bin/thrust ./bin/rails server -b "0.0.0.0"
