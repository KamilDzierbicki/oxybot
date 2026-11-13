# Draft model for scheduled email reports (not wired to the UI yet)
class ScheduledDelivery < ApplicationRecord
  belongs_to :report
  enum :frequency, { daily: 0, weekly: 1, monthly: 2 }

  validates :recipients, presence: true
end
