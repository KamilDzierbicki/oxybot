# A product analytics tool (Amplitude, Pendo, Hex) that tells launch reviews how many users used a feature each
# week, before and after its release. Each feature names its own key: the event, feature id or metric to count.
module Integration::Analytics
  extend ActiveSupport::Concern

  WEEKS = 4

  def analytics? = true

  # [{ week: Date (Monday), users: Integer }] from WEEKS before the release to WEEKS after it (or today)
  def weekly_usage(feature)
    released = feature.released_at.to_date
    client.weekly_users(feature.analytics_key, from: (released - WEEKS.weeks).beginning_of_week, to: [ released + WEEKS.weeks, Date.current ].min)
  end
end
