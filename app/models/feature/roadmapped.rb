# A feature's place on the roadmap: Now, Next or Later, or off the roadmap. Within a lane, priority then demand order it.
module Feature::Roadmapped
  extend ActiveSupport::Concern

  LANES = { "now" => "Now", "next" => "Next", "later" => "Later" }.freeze

  included do
    validates :roadmap_lane, inclusion: { in: LANES.keys }, allow_nil: true
    scope :on_roadmap, -> { where.not(roadmap_lane: nil) }
    scope :recently_released, -> { where(status: "released").where(released_at: 90.days.ago..).order(released_at: :desc) }
  end

  def lane_name = LANES[roadmap_lane]

  # The lane to the left or right, for the move buttons
  def neighbour_lane(step)
    keys = LANES.keys
    index = keys.index(roadmap_lane)
    keys[index + step] if index && (index + step).between?(0, keys.size - 1)
  end
end
