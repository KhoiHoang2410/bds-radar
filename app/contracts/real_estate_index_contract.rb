require "dry/validation"

# Validates filter params for GET /real_estates.
class RealEstateIndexContract < Dry::Validation::Contract
  params do
    optional(:province_id).filled(:integer)
    optional(:ward_city_id).filled(:integer)
    optional(:district_or_city).filled(:string)
    optional(:type).filled(included_in?: RealEstate::TYPES)
    optional(:status).filled(included_in?: RealEstate::STATUSES)
    optional(:min_price).filled(:integer)
    optional(:max_price).filled(:integer)
    optional(:min_area).filled(:float)
    optional(:max_area).filled(:float)
    optional(:bbox).filled(:string)
  end

  rule(:bbox) do
    next unless key? && value.present?

    parts = value.split(",")
    unless parts.size == 4 && parts.all? { |p| Float(p, exception: false) }
      key.failure("must be sw_lat,sw_lng,ne_lat,ne_lng")
    end
  end

  rule(:max_price, :min_price) do
    if values[:min_price] && values[:max_price] && values[:max_price] < values[:min_price]
      key.failure("must be >= min_price")
    end
  end
end
