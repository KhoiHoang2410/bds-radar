require "dry/validation"

# Validates optional filters for GET /real_estate_sources.
class RealEstateSourceIndexContract < Dry::Validation::Contract
  params do
    optional(:supplier).filled(:string)
    optional(:province_id).filled(:integer)
    optional(:status).filled(included_in?: RealEstateSource::STATUSES)
  end
end
