class RealEstate < ApplicationRecord
  self.inheritance_column = nil # `type` is the property-type attribute, not STI

  STATUSES = %w[active inactive].freeze
  TYPES = %w[condo house land commercial other].freeze

  # Canonical crawl province (filter key); named crawl_province to avoid clashing
  # with the raw `province` display string.
  belongs_to :crawl_province, class_name: "Province", foreign_key: :province_id, inverse_of: :real_estates
  belongs_to :ward_city, optional: true
  belongs_to :real_estate_source

  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }
  scope :inactive, -> { where(status: "inactive") }

  # Ransack allowlist (filtering): province → province_id, ward → ward_city_id,
  # district raw, type/status, price/area ranges, and lat/lng (bbox = *_gteq/_lteq).
  def self.ransackable_attributes(_auth = nil)
    %w[province_id ward_city_id district_or_city type status price area latitude longitude]
  end

  def self.ransackable_associations(_auth = nil)
    []
  end

  # Derived from coords, never stored (ADR-0001).
  def map_url
    return nil if latitude.blank? || longitude.blank?

    "https://www.google.com/maps?q=#{latitude},#{longitude}"
  end
end
