# lib/tasks/twitter_live_script.rb

require 'twitter'

stream = Twitter::Streaming::Client.new do |config|
  config.consumer_key        = ENV['CONSUMER_API_KEY']
  config.consumer_secret     = ENV['CONSUMER_API_SECRET']
  config.access_token        = ENV['ACCESS_TOKEN']
  config.access_token_secret = ENV['ACCESS_TOKEN_SECRET']
end

# Filter out suspiciously geolocated tweets
def farallon_islands_spam?(tweet_coordinates_hash)
  coordinates_array = tweet_coordinates_hash[:coordinates]
  long = coordinates_array[0]
  lat = coordinates_array[1]
  long.between?(-123.1, -122.9) && lat.between?(37.6, 37.8)
end

# Filter out incorrect geolocated tweets from Twitter API
def not_bay_area_coordinates?(tweet_coordinates_hash)
  coordinates_array = tweet_coordinates_hash[:coordinates]
  long = coordinates_array[0]
  lat = coordinates_array[1]
  !long.between?(-123.632497, -121.4099121094) || !lat.between?(36.9476967925, 38.5288302896)
end

# Blacklists remove job posting accounts & tweets
screen_name_blacklist = [
  "Job", "job", "Jobs", "job", "Careers", "careers", "test5geo1798",
  "tmj_", "WorkAt"
]

job_posting_blacklist = [
  "See our latest", "We're #hiring!", "Read about our latest #job opening",
  "Want to work in", "Can you recommend anyone for this",
  "Want to work at", "If you're looking for work in"
]

# Coordinates set up, roughly, to the greater SF Bay Area
stream.filter(locations: "-123.632497,36.9476967925,-121.4099121094,38.5288302896") do |tweet|
  # Only consider tweets with proper geolocation data
  if tweet.attrs[:coordinates]
    unless job_posting_blacklist.any? { |phrase| tweet.text.include?(phrase) } ||
      screen_name_blacklist.any? { |term| tweet.user.screen_name.include?(term) } ||
      farallon_islands_spam?(tweet.attrs[:coordinates]) ||
      not_bay_area_coordinates?(tweet.attrs[:coordinates])

      cache_tweet = Tweet.create!(
      text: tweet.text,
      name: tweet.user.name,
      screen_name: tweet.user.screen_name,
      location: tweet.user.location,
      url: tweet.user.to_h[:url],
      description: tweet.user.description,
      profile_picture: tweet.user.to_h[:profile_image_url_https],
      coordinates: tweet.to_h[:coordinates],
      retweet_count: tweet.retweet_count,
      favorite_count: tweet.favorite_count,
      tweet_id: tweet.to_h[:id_str],
      tweet_created_at: tweet.to_h[:created_at],
      time_utc: (Time.now.to_i * 1000)
      )

      # Write tweet data to Redis via Rails cache
      Rails.cache.write(cache_tweet.id, cache_tweet)
    end
  end
end
