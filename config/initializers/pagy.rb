require "pagy/extras/limit"     # client-overridable page size (?per_page=)
require "pagy/extras/overflow"  # out-of-range pages return empty, not an error

Pagy::DEFAULT[:limit] = 25         # default items per page
Pagy::DEFAULT[:limit_param] = :per_page
Pagy::DEFAULT[:limit_max] = 100    # cap to protect the DB
Pagy::DEFAULT[:overflow] = :empty_page
