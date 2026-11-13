class ExportJob < ApplicationJob
  queue_as :exports

  # Builds the CSV for a report export and uploads it to S3. Large reports take up to 2 minutes.
  # A PDF export would render the dashboard with Chromium here and needs the company logo from Account#branding.
  def perform(export)
    csv = export.report.to_csv
    export.file.attach(io: StringIO.new(csv), filename: "#{export.report.slug}.csv")
    export.update!(status: :done)
  end
end
