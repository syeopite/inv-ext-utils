require "kemal"
require "./kemal_handler.cr"

# Allows writing an extension module for Invidious
#
# All extensions must extend from `InvExtUtils::Extension` and define a `#load` method
module InvExtUtils
  VERSION = "0.1.0"

  # Represents an Invidious extension. All extensions should **extend** this module.
  module Extension
    # Loads the extension into Invidious
    def invidious_load()
      # As this shard will be eventually loaded by the main Invidious program
      # it will also have access to the top level methods imported by Kemal
      # and any other top level methods created by Invidious
      #
      # TODO: Add stub methods in an optional file as so test compilations can be done
      # with just the extension itself.
      add_handler InvExtUtils::Routing::EXT_BEFORE_AFTER_HANDLER
      load()
    end

    abstract def load()
  end

  # The Routing module allows you to extend Invidious' routes
  # This module provides macros to create and override routes
  # As well as adding before and after handlers as to modify
  # the response provided by Invidious.
  #
  # Use by **including** this module with `include`
  module Routing
    EXT_BEFORE_AFTER_HANDLER = InvExtUtils::RoutingHandler.new()

    private HTTP_METHODS   = %w(get post put patch delete options)

    # Add macros for setting before and after handlers for routes
    # called as extinv_before_[http method] and inv_after_[http method]
    {% for type in ["before", "after"] %}
      {% for method in HTTP_METHODS %}
        # Adds a handler that executes {{type.id}} the response
        macro extinv_{{type.id}}_{{method.id}}(path, controller, handler)
          unless Kemal::Utils.path_starts_with_slash?(\{{path}})
            raise Kemal::Exceptions::InvalidPathStartException.new({{method.id.stringify}}, \{{path}})
          end

          EXT_BEFORE_AFTER_HANDLER.{{type.id}}({{method.id.stringify}}.upcase, \{{path}}) do | env |
            \{{controller}}.\{{handler.id}}(env)
          end
        end
      {% end %}
    {% end %}
  end
end
