# Pagination metadata returned alongside every index collection.
Pagination = Struct.new(:page, :per_page, :total_count, :total_pages, keyword_init: true)
