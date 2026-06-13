class Ward < ApplicationRecord
  belongs_to :province

  validates :ward, presence: true
  validates :ward, uniqueness: { scope: :province_id }
  validate :ward_alternatives_unique_within_province

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
