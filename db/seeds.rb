puts "Seeding demo data…"

owner = User.find_or_initialize_by(email: "demo@socialportal.test")
if owner.new_record?
  owner.assign_attributes(name: "Demo Owner", password: "password123", password_confirmation: "password123")
  owner.save!
  puts "  Created user demo@socialportal.test / password123"
end

editor = User.find_or_initialize_by(email: "editor@socialportal.test")
if editor.new_record?
  editor.assign_attributes(name: "Demo Editor", password: "password123", password_confirmation: "password123")
  editor.save!
end

company = Company.find_or_create_by!(slug: "kamagram") do |c|
  c.name = "Kamagram"
  c.website = "https://kamagram.com"
  c.timezone = "UTC"
  c.description = "Demo brand seeded for the social portal."
end

Membership.find_or_create_by!(user: owner, company: company) { |m| m.role = "owner" }
Membership.find_or_create_by!(user: editor, company: company) { |m| m.role = "editor" }
owner.update!(current_company: company)

instagram = company.social_channels.find_or_create_by!(platform: "instagram", handle: "@kamagram") do |c|
  c.display_name = "Kamagram"
  c.status = "active"
end

linkedin = company.social_channels.find_or_create_by!(platform: "linkedin", handle: "kamagram") do |c|
  c.display_name = "Kamagram on LinkedIn"
  c.status = "active"
end

twitter = company.social_channels.find_or_create_by!(platform: "twitter", handle: "@kamagram") do |c|
  c.display_name = "Kamagram on X"
  c.status = "active"
end

samples = [
  { caption: "We're hiring engineers who care about their craft. Apply on our careers page.",
    hashtags: "#hiring #engineering",
    status: "draft",
    schedule: 5.days.from_now,
    channels: [ instagram, linkedin ] },

  { caption: "Behind the scenes from this week's offsite. Strategy, sticky notes, and so much coffee.",
    hashtags: "#teamlife #offsite",
    status: "pending_review",
    schedule: 3.days.from_now,
    channels: [ instagram ] },

  { caption: "Big launch incoming. Tap the link in bio to be the first to know.",
    hashtags: "#launch #soon",
    status: "approved",
    schedule: 2.days.from_now.change(hour: 10),
    channels: [ instagram, twitter ] },

  { caption: "Customer story: how Acme Foods grew engagement 3x in 90 days using our scheduling.",
    hashtags: "#customerstory #growth",
    status: "scheduled",
    schedule: 1.day.from_now.change(hour: 14),
    channels: [ instagram, linkedin ] },

  { caption: "Three quick tips for making your captions hook readers in the first 7 words.",
    hashtags: "#copywriting #socialmedia",
    status: "published",
    schedule: 6.days.ago.change(hour: 9),
    channels: [ instagram, linkedin, twitter ] },

  { caption: "Recap of last month's product updates. Reply with what you'd like to see next!",
    hashtags: "#productupdate",
    status: "published",
    schedule: 12.days.ago.change(hour: 11),
    channels: [ instagram ] }
]

samples.each_with_index do |s, idx|
  post = company.posts.find_or_initialize_by(caption: s[:caption])
  post.author = owner
  post.title = "Demo post #{idx + 1}"
  post.hashtags = s[:hashtags]
  post.status = s[:status]
  post.scheduled_at = s[:schedule]
  if %w[approved scheduled published].include?(s[:status])
    post.approved_by = owner
    post.approved_at = (s[:schedule] - 1.day)
  end
  post.save!

  s[:channels].each do |channel|
    cp = post.channel_posts.find_or_initialize_by(social_channel: channel)
    if s[:status] == "published"
      cp.status = "published"
      cp.published_at = s[:schedule]
      cp.external_id = "demo_#{post.id}_#{channel.id}"
    else
      cp.status = "pending"
    end
    cp.save!

    next unless s[:status] == "published"
    6.times do |i|
      captured = (s[:schedule] + (i * 12.hours))
      next if captured > Time.current
      likes = (rand(80..220) * (i + 1) * 0.6).to_i
      comments = (rand(5..25) * (i + 1) * 0.5).to_i
      shares = rand(3..18)
      saves = rand(8..30)
      reach = (likes + comments + shares + saves) * rand(8..15)
      impressions = (reach * rand(1.1..1.6)).to_i
      rate = reach.positive? ? ((likes + comments + shares + saves).to_f / reach * 100).round(2) : 0
      cp.post_metrics.find_or_create_by!(captured_at: captured) do |m|
        m.likes = likes
        m.comments = comments
        m.shares = shares
        m.saves = saves
        m.reach = reach
        m.impressions = impressions
        m.engagement_rate = rate
      end
    end
  end
end

puts "Seed complete."
puts "  Sign in: demo@socialportal.test / password123"
puts "  Company: #{company.name} (slug: #{company.slug})"
