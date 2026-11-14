# Weekly users for analytics integrations in test mode: stable sample numbers derived from the key, rising after
# the middle of the range like a release. Launch reviews label them as sample numbers.
module Integration::SampleUsage
  module_function

  def weekly_users(key, from:, to:)
    seed = Zlib.crc32(key.to_s)
    weeks = (from.beginning_of_week..to).step(7).to_a
    weeks.each_with_index.map do |week, index|
      base = 40 + seed % 60
      { week: week, users: base + (index >= weeks.size / 2 ? base * (index - weeks.size / 2 + 1) / 3 : (seed >> index) % 7) }
    end
  end
end
