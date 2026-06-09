class Province < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :fetch_page_depth, numericality: { only_integer: true, greater_than: 0 }

  scope :scheduled, -> { where(schedule_fetch: true) }
end
