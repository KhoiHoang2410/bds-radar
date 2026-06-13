# Best-effort: find a known condo project name inside a free-text listing title.
#
# The dictionary is the set of project names we already extract *structurally* from
# nhatot (RealEstateSource#project_name). Suppliers that don't expose a project field
# (mogi) only mention the project in the title prose, so we recognize it by fuzzy
# containment (StringMatcher) against that dictionary. High precision (we only ever
# return a name we've already seen), partial recall (a project nhatot never listed
# won't be found).
#
# Returns the canonical dictionary spelling, or nil. On several matches: closest first
# (lowest distance), ties broken by the longest — most specific — name.
class ProjectMatcher
  MIN_NAME_LENGTH = 5 # ignore very short names — they substring-match noisily
  MAX_ERROR = 2

  def self.match(title, dictionary: self.dictionary)
    return nil if title.to_s.strip.empty?

    scored = dictionary.filter_map do |name|
      distance = StringMatcher.receive(title, name, max_error: MAX_ERROR)
      [ name, distance ] if distance
    end
    return nil if scored.empty?

    best = scored.map(&:last).min
    scored.select { |(_, d)| d == best }.map(&:first).max_by(&:length)
  end

  # Distinct nhatot project names long enough to match safely. Loaded once per
  # normalize run and injected into #match (don't re-query per listing).
  def self.dictionary
    RealEstateSource.where(supplier: "nhatot")
                    .where.not(project_name: nil)
                    .distinct
                    .pluck(:project_name)
                    .select { |name| name.gsub(/[^[:alnum:]]/, "").length >= MIN_NAME_LENGTH }
  end
end
