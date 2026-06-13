class Ward < ApplicationRecord
  FUZZY_MAX_ERROR = 2 # max edit distance for a fuzzy ward match

  belongs_to :province

  validates :ward, presence: true
  validates :ward, uniqueness: { scope: :province_id }
  validate :ward_alternatives_unique_within_province

  # Resolves a messy supplier ward string to a canonical Ward within a known province,
  # best-effort: exact → alternatives → fuzzy (StringMatcher), and **nil on ambiguity**
  # (a numbered ward that fuzzy-matches several wards equally well). Never raises; a nil
  # match is valid (the RealEstate is still mappable via coords — ADR-0001). Province is
  # an exact FK scope — callers pass the canonical province_id they already hold.
  def self.match(ward:, province_id:)
    query = ward.to_s.strip
    return nil if query.blank? || province_id.blank?

    candidates = where(province_id: province_id).to_a
    return nil if candidates.empty?

    (exact_match(candidates, query) || alias_match(candidates, query) || fuzzy_match(candidates, query))&.id
  end

  def self.exact_match(candidates, query)
    candidates.find { |w| w.ward == query }
  end

  def self.alias_match(candidates, query)
    down = query.downcase
    candidates.find { |w| w.ward_alternatives.any? { |a| a.to_s.downcase == down } }
  end

  # Score each candidate by the closest of its (canonical name + alternatives) as a
  # fuzzy substring of the supplier string; pick the best, but return nil on a tie.
  def self.fuzzy_match(candidates, query)
    scored = candidates.filter_map do |w|
      names = [ w.ward, *w.ward_alternatives ]
      distance = names.filter_map { |n| StringMatcher.receive(query, n, max_error: FUZZY_MAX_ERROR) }.min
      [ w, distance ] if distance
    end
    return nil if scored.empty?

    best = scored.map(&:last).min
    winners = scored.select { |(_, d)| d == best }.map(&:first)
    winners.one? ? winners.first : nil # tie ⇒ ambiguous ⇒ nil
  end
  private_class_method :exact_match, :alias_match, :fuzzy_match

  private

  # App-level guard: an alias must point at exactly one ward within a province, else
  # the matcher could resolve it two ways. Reject a ward_alternative that collides with
  # another row's canonical ward or alternatives in the same province.
  def ward_alternatives_unique_within_province
    return if ward_alternatives.blank?

    mine = ward_alternatives.map { |a| a.to_s.downcase.strip }
    others = Ward.where(province_id: province_id).where.not(id: id)
    taken = others.flat_map { |w| [ w.ward, *w.ward_alternatives ] }.map { |s| s.to_s.downcase.strip }

    clash = mine & taken
    return if clash.empty?

    errors.add(:ward_alternatives, "collide with another ward in province #{province_id}: #{clash.join(', ')}")
  end
end
