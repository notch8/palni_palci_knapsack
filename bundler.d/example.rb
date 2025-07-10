# frozen_string_literal: true
# see https://github.com/kbrock/bundler-inject/tree/gem_path

# specify one or more ruby files in this directory to be injected into bundler
# you can use `gem` to add new gems, `override_gem` to change an existing gem
# or `ensure_gem` to make sure a gem is there w/o worrying about if it is an
# override or not

ensure_gem "sentry-ruby"
ensure_gem "sentry-rails"
ensure_gem "cancancan", "~> 3.0" # cancancan is bundling to v1.17.0 but we need at least 3.0

override_gem "hyrax",
             github: "samvera/hyrax",
             ref: "d6330a1c048bd498da852325a502f8dba0467c11"
             