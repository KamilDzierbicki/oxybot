namespace :oxybot do
  desc "Embed every insight and feature again (after changing the embedding model)"
  task reembed: :environment do
    [ Feature, Insight ].each do |model|
      count = 0
      model.find_each do |record|
        record.embed
        count += 1
      end
      puts "#{model.name}: #{count} embedded"
    end
  end
end
