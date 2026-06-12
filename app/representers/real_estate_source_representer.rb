class RealEstateSourceRepresenter < Roar::Decorator
  include Roar::JSON

  property :id
  property :supplier
  property :external_id
  property :status
  property :source_url
  property :type
  property :price
  property :area, getter: ->(*) { area&.to_f }
  property :address
  property :province
  property :district_or_city
  property :ward
  property :street
  property :image_urls
  property :latitude, getter: ->(*) { latitude&.to_f }
  property :longitude, getter: ->(*) { longitude&.to_f }
  property :bedrooms
  property :bathrooms
  property :posted_at
  property :title
  property :last_seen_at
end
