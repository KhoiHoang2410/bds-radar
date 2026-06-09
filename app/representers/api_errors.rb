# Wrapper so ErrorRepresenter can render { "errors": { field => [messages] } }.
ApiErrors = Struct.new(:errors, keyword_init: true)
