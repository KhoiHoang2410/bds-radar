class RealEstatesRepresenter < Roar::Decorator
  include Roar::JSON

  collection :real_estates, decorator: RealEstateRepresenter
end
