class Report < ApplicationRecord
  belongs_to :dashboard
  has_many :exports, dependent: :destroy

  # CSV export only; PDF export was requested by enterprise customers but is not built yet.
  # Rendering charts server-side needs a headless browser (see ExportJob).
  def export(format:)
    raise ArgumentError, "unsupported format #{format}" unless format == :csv

    exports.create!(format: format).tap(&:enqueue)
  end
end
