require "dry/validation"

# Validates the writable fields of a Province toggle (PATCH /provinces/:id).
class ProvinceUpdateContract < Dry::Validation::Contract
  params do
    optional(:schedule_fetch).filled(:bool)
    optional(:fetch_page_depth).filled(:integer, gt?: 0)
  end
end
