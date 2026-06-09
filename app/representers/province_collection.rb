# Wrapper so ProvincesRepresenter can render { "provinces": [ ... ] }.
ProvinceCollection = Struct.new(:provinces, keyword_init: true)
