# frozen_string_literal: true

# Require so constant is available when this initializer runs (engine app may not be autoloaded yet)
require HykuKnapsack::Engine.root.join('app', 'services', 'listeners', 'cdl_listener.rb').to_s

Hyrax.publisher.subscribe(Listeners::CdlListener.new)
