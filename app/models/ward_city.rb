class WardCity < ApplicationRecord
  validates :ward, presence: true
  validates :province, presence: true
  validates :ward, uniqueness: { scope: :province }
  validate :ward_alternatives_unique_within_province

  private

  # App-level guard: an alias must point at exactly one ward within a province, else
  # the matcher could resolve it two ways. Reject a ward_alternative that collides with
  # another row's canonical ward or alternatives in the same province.
  def ward_alternatives_unique_within_province
    return if ward_alternatives.blank?

    mine = ward_alternatives.map { |a| a.to_s.downcase.strip }
    others = WardCity.where(province: province).where.not(id: id)
    taken = others.flat_map { |wc| [ wc.ward, *wc.ward_alternatives ] }.map { |s| s.to_s.downcase.strip }

    clash = mine & taken
    return if clash.empty?

    errors.add(:ward_alternatives, "collide with another ward in #{province}: #{clash.join(', ')}")
  end
end
