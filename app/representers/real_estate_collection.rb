# Wrapper so RealEstatesRepresenter can render { "real_estates": [ ... ] }.
RealEstateCollection = Struct.new(:real_estates, keyword_init: true)
