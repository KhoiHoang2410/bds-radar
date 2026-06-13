# Resolves a messy supplier ward string to a canonical Ward within a known province,
# best-effort: exact → alternatives → fuzzy, and **nil on ambiguity** (a numbered ward
# that fuzzy-matches several wards equally well). Never raises; a nil match is valid
# (the RealEstate is still mappable via coords — ADR-0001).
#
# Province is no longer fuzzy: callers pass the canonical province_id (the crawl
# province they already hold), so candidates scope directly by the FK.
class WardMatcher
  FUZZY_THRESHOLD = 2 # max edit distance for a fuzzy candidate

  def self.call(ward:, province_id:)
    new(ward: ward, province_id: province_id).call
  end

  def initialize(ward:, province_id:)
    @ward = ward.to_s.strip
    @province_id = province_id
  end

  def call
    return nil if @ward.blank? || @province_id.blank?

    candidates = Ward.where(province_id: @province_id).to_a
    return nil if candidates.empty?

    match = exact_match(candidates) || alias_match(candidates) || fuzzy_match(candidates)
    match&.id
  end

  private

  def exact_match(candidates)
    candidates.find { |w| w.ward == @ward }
  end

  def alias_match(candidates)
    down = @ward.downcase
    candidates.find { |w| w.ward_alternatives.any? { |a| a.to_s.downcase == down } }
  end

  def fuzzy_match(candidates)
    target = normalize(@ward)
    scored = candidates.map do |w|
      names = [ w.ward, *w.ward_alternatives ].map { |n| normalize(n) }
      [ w, names.map { |n| distance(target, n) }.min ]
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
