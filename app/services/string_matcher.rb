# Pure-string fuzzy containment: is `string_b` present somewhere in `string_a` within
# an acceptable edit distance? Both inputs are normalized first (Vietnamese diacritics
# stripped, lowercased, reduced to alphanumerics + single spaces).
#
# Returns the minimal edit distance of `string_b` against the best-matching substring
# of `string_a` when that distance is <= max_error, else nil. nil reads as "no match";
# the number lets callers rank candidates (lower = closer).
#
# Two callers, two shapes of the same question:
#   - Ward.match  — is a canonical ward name present in a messy supplier string?
#   - ProjectMatcher — is a known project name present in a listing title?
class StringMatcher
  DEFAULT_MAX_ERROR = 2

  def self.receive(string_a, string_b, max_error: DEFAULT_MAX_ERROR)
    new(string_a, string_b, max_error: max_error).receive
  end

  def initialize(string_a, string_b, max_error: DEFAULT_MAX_ERROR)
    @haystack = normalize(string_a)
    @needle = normalize(string_b)
    @max_error = max_error
  end

  def receive
    return nil if @haystack.empty? || @needle.empty?

    distance = approximate_substring_distance
    distance <= @max_error ? distance : nil
  end

  private

  # Levenshtein where the needle may begin anywhere in the haystack: row 0 is all-zero
  # (matching the empty needle costs nothing at any offset), and the answer is the min
  # of the final row (the best end position). O(|needle| * |haystack|).
  def approximate_substring_distance
    haystack = @haystack.chars
    prev = Array.new(haystack.length + 1, 0)

    @needle.chars.each_with_index do |nc, i|
      cur = [ i + 1 ] # matching needle[0..i] against an empty prefix needs i+1 deletions
      haystack.each_with_index do |hc, j|
        cost = nc == hc ? 0 : 1
        cur << [ prev[j + 1] + 1, cur[j] + 1, prev[j] + cost ].min
      end
      prev = cur
    end

    prev.min
  end

  # Lowercase, strip Vietnamese diacritics (NFD → drop combining marks; đ→d), and
  # reduce to alphanumerics + single spaces.
  def normalize(str)
    s = str.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "")
    s.tr("đĐ", "dd").downcase.gsub(/[^a-z0-9\s]/, " ").squish
  end
end
