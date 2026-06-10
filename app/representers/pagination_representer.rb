class PaginationRepresenter < Roar::Decorator
  include Roar::JSON

  property :page
  property :per_page
  property :total_count
  property :total_pages
end
