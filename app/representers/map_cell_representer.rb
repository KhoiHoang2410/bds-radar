class MapCellRepresenter < Roar::Decorator
  include Roar::JSON

  property :lat
  property :lng
  property :count
  property :median_price
  property :price_per_m2
end
