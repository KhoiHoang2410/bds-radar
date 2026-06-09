# Wrapper so RealEstateSourcesRepresenter can render { "real_estate_sources": [ ... ] }.
RealEstateSourceCollection = Struct.new(:real_estate_sources, keyword_init: true)
