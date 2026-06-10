class Province < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :fetch_page_depth, numericality: { only_integer: true, greater_than: 0 }

  has_many :real_estate_sources, foreign_key: :province_id, inverse_of: :crawl_province, dependent: :destroy

  scope :scheduled, -> { where(schedule_fetch: true) }
end
