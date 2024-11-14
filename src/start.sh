#!/bin/bash

rm -f ./tmp/pids/server.pid

# Precompile assets
bundle exec rails assets:precompile

# Start Rails server
bundle exec rails server -b "0.0.0.0"
