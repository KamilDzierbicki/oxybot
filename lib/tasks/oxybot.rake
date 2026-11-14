namespace :oxybot do
  desc "Embed stale vectors again in the background, per workspace and in batches (ACCOUNT_ID=1 for one workspace)"
  task reembed: :environment do
    accounts = ENV["ACCOUNT_ID"] ? Account.where(id: ENV["ACCOUNT_ID"]) : Account.all
    accounts.find_each do |account|
      stale = account.features.stale_embeddings.count + account.insights.stale_embeddings.count
      next puts("#{account.name}: up to date") if stale.zero?

      ReembedJob.perform_later(account)
      puts "#{account.name}: #{stale} stale vectors queued"
    end
  end

  desc "Show which embedding model made each workspace's vectors"
  task embeddings: :environment do
    active = EmbeddingSpace.active
    puts "Active model: #{active ? "#{active.name} (space #{active.id}, since #{active.activated_at.to_fs(:short)})" : "none yet"}"
    Account.find_each do |account|
      total = account.features.count + account.insights.count
      stale = account.features.stale_embeddings.count + account.insights.stale_embeddings.count
      puts "#{account.name}: #{total - stale} of #{total} current"
    end
  end
end
