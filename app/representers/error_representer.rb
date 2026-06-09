# Renders validation/error payloads as { "errors": { field => [messages] } }.
# Wrap a plain hash: ErrorRepresenter.new(ApiErrors.new(errors: { ... })).to_json
class ErrorRepresenter < Roar::Decorator
  include Roar::JSON

  property :errors
end
