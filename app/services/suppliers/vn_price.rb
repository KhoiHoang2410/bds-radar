module Suppliers
  # Parses Vietnamese price strings into VND integers.
  #   "8 tỷ 250 triệu" => 8_250_000_000   ("tỷ" = 1e9, "triệu" = 1e6)
  #   "1,5 tỷ"         => 1_500_000_000   (comma = decimal separator)
  #   "950 triệu"      => 950_000_000
  module VnPrice
    BILLION = 1_000_000_000
    MILLION = 1_000_000

    module_function

    def parse(text)
      return nil if text.to_s.strip.empty?

      t = text.to_s.downcase
      ty = t[/([\d.,]+)\s*tỷ/, 1]
      trieu = t[/([\d.,]+)\s*triệu/, 1]
      return nil unless ty || trieu

      total = 0
      total += to_number(ty) * BILLION if ty
      total += to_number(trieu) * MILLION if trieu
      total.round
    end

    # VN convention: "." groups thousands, "," is the decimal point.
    def to_number(str)
      str.tr(".", "").tr(",", ".").to_f
    end
  end
end
