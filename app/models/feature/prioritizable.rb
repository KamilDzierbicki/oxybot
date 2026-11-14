# RICE: Reach x Impact x Confidence / Effort. Reach is the number of distinct customers asking for the feature,
# counted from linked insights, so it moves with the evidence; people set impact, confidence and effort.
module Feature::Prioritizable
  extend ActiveSupport::Concern

  IMPACTS = { 3.0 => "Massive (3)", 2.0 => "High (2)", 1.0 => "Medium (1)", 0.5 => "Low (0.5)", 0.25 => "Minimal (0.25)" }.freeze
  CONFIDENCES = { 100 => "High (100%)", 80 => "Medium (80%)", 50 => "Low (50%)" }.freeze

  included do
    validates :impact, inclusion: { in: IMPACTS.keys }, allow_nil: true
    validates :confidence, inclusion: { in: CONFIDENCES.keys }, allow_nil: true
    validates :effort, numericality: { greater_than: 0, less_than: 10_000 }, allow_nil: true
  end

  # Reach comes from with_demand (customer_count); outside that scope it is counted here
  def reach
    has_attribute?(:customer_count) ? self[:customer_count].to_i : insights.distinct.count(:customer_id)
  end

  def rice_score
    return unless impact && confidence && effort

    (reach * impact * confidence / 100.0 / effort).round(1)
  end

  def rice_missing = { "impact" => impact, "confidence" => confidence, "effort" => effort }.select { |_, value| value.nil? }.keys
end
