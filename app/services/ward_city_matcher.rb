# Resolves a messy supplier admin path to a canonical WardCity, best-effort:
#   exact → alternatives → fuzzy, and **nil on ambiguity** (a numbered ward that
#   fuzzy-matches several wards equally well). Never raises; a nil match is valid
#   (the RealEstate is still mappable via coords — ADR-0001).
class WardCityMatcher
  FUZZY_THRESHOLD = 2 # max edit distance for a fuzzy candidate

  def self.call(ward:, province:)
    new(ward: ward, province: province).call
  end

  def initialize(ward:, province:)
    @ward = ward.to_s.strip
    @province = province.to_s.strip
  end

  def call
    return nil if @ward.blank? || @province.blank?

    candidates = candidates_in_province
    return nil if candidates.empty?

    match = exact_match(candidates) || alias_match(candidates) || fuzzy_match(candidates)
    match&.id
  end

  private

  # Scope to the province: exact rows first, else match canonical/alternative names
  # (normalized) so raw supplier drift like "Tp Hồ Chí Minh" still resolves.
  def candidates_in_province
    exact = WardCity.where(province: @province).to_a
    return exact if exact.any?

    pn = normalize(@province)
    WardCity.all.select do |wc|
      normalize(wc.province) == pn || wc.province_alternatives.any? { |a| normalize(a) == pn }
    end
  end

  def exact_match(candidates)
    candidates.find { |wc| wc.ward == @ward }
  end

  def alias_match(candidates)
    down = @ward.downcase
    candidates.find { |wc| wc.ward_alternatives.any? { |a| a.to_s.downcase == down } }
  end

  def fuzzy_match(candidates)
    target = normalize(@ward)
    scored = candidates.map do |wc|
      names = [ wc.ward, *wc.ward_alternatives ].map { |n| normalize(n) }
      [ wc, names.map { |n| distance(target, n) }.min ]
    end

    within = scored.select { |(_, d)| d <= FUZZY_THRESHOLD }
    return nil if within.empty?

    best = within.map(&:last).min
    winners = within.select { |(_, d)| d == best }.map(&:first)
    winners.one? ? winners.first : nil # tie ⇒ ambiguous ⇒ nil
  end

  # Lowercase, strip Vietnamese diacritics (NFD → drop combining marks; đ→d), and
  # reduce to alphanumerics + single spaces.
  def normalize(str)
    s = str.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "")
    s.tr("đĐ", "dd").downcase.gsub(/[^a-z0-9\s]/, " ").squish
  end

  def distance(a, b)
    return b.length if a.empty?
    return a.length if b.empty?

    prev = (0..b.length).to_a
    a.each_char.with_index do |ca, i|
      cur = [ i + 1 ]
      b.each_char.with_index do |cb, j|
        cost = ca == cb ? 0 : 1
        cur << [ cur[j] + 1, prev[j + 1] + 1, prev[j] + cost ].min
      end
      prev = cur
    end
    prev[b.length]
  end
end
