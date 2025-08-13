# frozen_string_literal: true
# see https://github.com/kbrock/bundler-inject/tree/gem_path

# specify one or more ruby files in this directory to be injected into bundler
# you can use `gem` to add new gems, `override_gem` to change an existing gem
# or `ensure_gem` to make sure a gem is there w/o worrying about if it is an
# override or not

gem "sentry-ruby"
gem "sentry-rails"
ensure_gem "cancancan", "~> 3.0" # cancancan is bundling to v1.17.0 but we need at least 3.0

ensure_gem "willow_sword", github: "notch8/willow_sword", ref: "bd43991e8e1b0c660fc29f94e7fec38e8ca03e1c"