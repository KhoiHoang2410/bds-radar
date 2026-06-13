require "dry/validation"

# Gates RealEstate assembly in normalize: every field the domain treats as mandatory
# must be present before a source becomes a RealEstate (CONTEXT.md "Mandatory fields"
# + coords + canonical province). A source that can't satisfy this is silently skipped
# — no partial RealEstate rows.
#
# Deliberately NOT required (nullable by design): ward_id (matcher returns nil on
# ambiguity — ADR-0001), bedrooms, bathrooms, posted_at, title (listing-detail drift;
# land/commercial have no rooms). Unknown keys are ignored by dry's params schema.
class RealEstateContract < Dry::Validation::Contract
  params do
    required(:latitude).filled
    required(:longitude).filled
    required(:province_id).filled(:integer)
    required(:real_estate_source_id).filled(:integer)
    required(:price).filled(:integer)
    required(:area).filled
    required(:type).filled(:string)
    required(:status).filled(:string)
    required(:province).filled(:string)
    required(:ward).filled(:string)
    required(:district_or_city).filled(:string)
    required(:image_urls).value(:array, min_size?: 1)
    required(:source_urls).value(:array, min_size?: 1)
  end
end
