# Middleware for the extension's before and after handlers
#
# As the extension is loaded after Invidious loads its own Kemal handlers,
# the extension's kemal handlers will have a lower priority than the ones Invidious creates.
#
# This also applies to the before_all and after_all routes in which the one Invidious defines
# will have a higher priority than one that is defined below
#
# Mostly based off of Kemal's own FilterHandler
class InvExtUtils::RoutingHandler < Kemal::Handler
  alias HANDLER_TYPE = Proc(HTTP::Server::Context, Nil)

  def initialize()
    @tree = Radix::Tree(Array(HANDLER_TYPE)).new
  end

    # The call order of the filters is `before_all -> before_x -> X -> after_x -> after_all`.
    def call(context : HTTP::Server::Context)
      return call_next(context) unless context.route_found?

      call_block_for_path_type(context.request.method, context.request.path, :before, context)

      if Kemal.config.error_handlers.has_key?(context.response.status_code)
        raise Kemal::Exceptions::CustomException.new(context)
      end

      call_next(context)

      call_block_for_path_type(context.request.method, context.request.path, :after, context)

      # However these after and after_all routes should still have lower priority than the
      # ones that Invidious defines

      return context
    end

  private def add_route_filter(verb : String, path, type, &block : HTTP::Server::Context -> _)
    lookup = lookup_filters_for_path_type(verb, path, type)

    if lookup.found? && lookup.payload.is_a?(Array(HANDLER_TYPE))
      lookup.payload << block
    else
      @tree.add radix_path(verb, path, type), [block]
    end
  end

  private def lookup_filters_for_path_type(verb : String?, path : String, type)
    @tree.find radix_path(verb, path, type)
  end

  private def radix_path(verb : String?, path : String, type : Symbol)
    "/#{type}/#{verb}/#{path}"
  end

  private def call_block_for_path_type(verb : String?, path : String, type, context : HTTP::Server::Context)
    lookup = lookup_filters_for_path_type(verb, path, type)
    if lookup.found? && lookup.payload.is_a? Array(HANDLER_TYPE)
      blocks = lookup.payload
      blocks.each &.call(context)
    end
  end

  def before(verb : String, path : String = "*", &block : HTTP::Server::Context -> _)
    self.add_route_filter verb, path, :before, &block
  end

  def after(verb : String, path : String = "*", &block : HTTP::Server::Context -> _)
    self.add_route_filter verb, path, :after, &block
  end
end
