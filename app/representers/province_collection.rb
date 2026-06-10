# Wrapper so ProvincesRepresenter can render { "provinces": [...], "pagination": {...} }.
ProvinceCollection = Struct.new(:provinces, :pagination, keyword_init: true)
