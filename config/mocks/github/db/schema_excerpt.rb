create_table "exports" do |t|
  t.references :report, null: false
  t.integer :status, default: 0
  t.string :format, null: false # "csv" today
  t.timestamps
end

create_table "accounts" do |t|
  t.jsonb :branding, default: {} # logo_url, primary_color
end
