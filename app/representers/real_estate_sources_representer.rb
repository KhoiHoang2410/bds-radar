class RealEstateSourcesRepresenter < Roar::Decorator
  include Roar::JSON

  collection :real_estate_sources, decorator: RealEstateSourceRepresenter
  property :pagination, decorator: PaginationRepresenter
end
