class RealEstateSource < ApplicationRecord
  self.inheritance_column = nil # `type` is the property-type attribute, not STI

  STATUSES = %w[active inactive].freeze

  # Canonical crawl unit the row was fetched under (sweep/scope key). Named
  # `crawl_province` so it doesn't collide with the raw parsed `province` string.
  belongs_to :crawl_province, class_name: "Province", foreign_key: :province_id, inverse_of: :real_estate_sources

  validates :supplier, presence: true
  validates :external_id, presence: true
  validates :external_id, uniqueness: { scope: :supplier }
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }
  scope :inactive, -> { where(status: "inactive") }
end
