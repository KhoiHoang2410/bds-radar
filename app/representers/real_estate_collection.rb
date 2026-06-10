# Wrapper so RealEstatesRepresenter can render { "real_estates": [ ... ] }.
RealEstateCollection = Struct.new(:real_estates, :pagination, keyword_init: true)
