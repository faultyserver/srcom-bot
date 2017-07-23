require "http"
require "json"
require "yaml"

require "kemal"

require "./srcombot/*"

CONFIG = {
  "target"  => ENV["DISCORD_TARGET_URL"],
  "games"   => ["yo1yq2dq", "8nd2wvd0", "qw6jv76j", "nj1n99dp", "29d3w01l", "om1m3j62", "xv1pj718", "xldezxd3", "om1mj412", "m9doj36p", "946w971r", "l3dxlpdy", "29d37g6l", "ok6qj9dg", "xldexx63", "xv1py818", "yd4kmk6e", "vo6gv562", "j1nyvy6p", "y657jede", "xkdkjq1m", "jy65041e", "n4d7pgd7", "kyd4051e", "j1lexz6g"]
}

def srcom_url_for(game)
  "http://www.speedrun.com/api/v1/runs?status=verified&orderby=verify-date&direction=desc&game=#{game}&embed=category,players,game,platform,region"
end

def post_run(run : JSON::Any)
  url           = run["weblink"]
  runners       = run["players"]["data"].map{ |p| p["names"]["international"] }.join(", ")
  run_time      = Time::Span.from(run["times"]["primary_t"].as_i, Time::Span::TicksPerSecond).to_s
  run_date      = run["date"]
  game_name     = run["game"]["data"]["names"]["international"]
  game_cover    = run["game"]["data"]["assets"]["cover-large"]["uri"]
  game_link     = run["game"]["data"]["weblink"]
  category      = run["category"]["data"]["name"]
  video_link    = run["videos"]["links"].first["uri"]
  comment       = run["comment"]
  fields = [
    {
      "name" => "Video",
      "value" => video_link,
      "inline" => false
    }
  ]

  if run["splits"]?
    fields.push({
      "name" => "Splits",
      "value" => run["splits"]["uri"],
      "inline" => false
    })
  end

  if run["region"]? && run["region"]["data"]? && run["region"]["data"]["name"]?
    fields.push({
      "name" => "Region",
      "value" => run["region"]["data"]["name"],
      "inline" => true
    })
  end

  fields.push({
    "name" => "Platform",
    "value" => run["platform"]["data"]["name"],
    "inline" => true
  })

  discord_payload = {
    "embeds" => [{
      "title" => "#{category} in #{run_time} by #{runners}",
      "url" => url,
      "description" => "#{comment}",
      "color" => 0x053452,
      "author" => {
        "name" => game_name,
        "url" => game_link
      },
      "thumbnail" => {
        "url" => game_cover
      },
      "fields" => fields
    }]
  }.to_json

  # Send the formatted webhook payload to Discord.
  HTTP::Client.post(CONFIG["target"].to_s, headers: HTTP::Headers{"Content-Type" => "application/json"}, body: discord_payload)
end

games = CONFIG["games"].as(Array(String)).map do |game_id|
  Game.new(game_id)
end


# Post a startup message
HTTP::Client.post(CONFIG["target"].to_s, headers: HTTP::Headers{"Content-Type" => "application/json"}, body: { "content" => "Hello! I'll be posting runs submitted to speedrun.com as they get verified." }.to_json)

spawn do
  loop do
    games.each do |game|
      puts "Checking for new runs for #{game.id}"
      # Run each game in a separate fiber to avoid killing the main process
      spawn do
        response = HTTP::Client.get(srcom_url_for(game.id))
        runs = JSON.parse(response.body)["data"]

        runs.each do |run|
          next unless run["status"]? && run["status"]["status"] != "verified"
          next unless Time.parse(run["status"]["verify-date"].as_s, "%FT%X%z") > game.last_checked_at
          puts "Found run to post: #{run}"
          post_run(run)
        end
      end

      sleep(5)
    end

    # Check every 5 minutes
    sleep(50*60)
  end
end

Kemal.run
