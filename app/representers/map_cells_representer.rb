class MapCellsRepresenter < Roar::Decorator
  include Roar::JSON

  collection :cells, decorator: MapCellRepresenter
  property :precision # decimal places lat/lng were snapped to (bin size)
end
