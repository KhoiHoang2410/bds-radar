class RealEstateRepresenter < Roar::Decorator
  include Roar::JSON

  property :id
  property :type
  property :price
  property :area, getter: ->(*) { area&.to_f }
  property :province_id
  property :province
  property :district_or_city
  property :ward
  property :ward_city_id
  property :latitude, getter: ->(*) { latitude&.to_f }
  property :longitude, getter: ->(*) { longitude&.to_f }
  property :image_urls
  property :source_urls
  property :status
  property :map_url # derived from coords, never stored (ADR-0001)
end
