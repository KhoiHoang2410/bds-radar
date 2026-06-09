# Wraps a collection as { "provinces": [ ... ] }.
# Build with: ProvincesRepresenter.new(ProvinceCollection.new(provinces: relation.to_a))
class ProvincesRepresenter < Roar::Decorator
  include Roar::JSON

  collection :provinces, decorator: ProvinceRepresenter
end
