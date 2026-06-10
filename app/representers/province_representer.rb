class ProvinceRepresenter < Roar::Decorator
  include Roar::JSON

  property :id
  property :name
  property :alternatives
  property :schedule_fetch
  property :fetch_page_depth
end
