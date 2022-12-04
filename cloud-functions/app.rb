require 'functions_framework'
require 'nokogiri'
require 'slack-notifier'
require 'open-uri'
require 'simple_twitter'

def scrape
  url = ENV['SCRAPE_URL']
  html = URI.open(url).read
  doc = Nokogiri::HTML.parse(html)

  status = doc.at_css('#mdServiceStatus').at_css('dt').text.strip
  message = doc.at_css('#mdServiceStatus').at_css('dd').text.strip

  { status: status, message: message }
end

def tweet
  endpoint = ENV['TWITTER_ENDPOINT']
  bearer_token = ENV['BEARER_TOKEN']

  client = SimpleTwitter::Client.new(bearer_token: bearer_token)
  response = client.get(endpoint, query: '西武池袋線')
  fields = response.fetch(:data).map.with_index do |data, i|
    {
      title: "tweet#{i}",
      value: data.fetch(:text)
    }
  end

  attachment = {
    color: 'success',
    fields: fields
  }
  slack_notify('西武池袋線に関するツイート', attachment)
end

def slack_notify(text, attachment = [])
  notifier = Slack::Notifier.new(ENV['SLACK_WEBHOOK_URL'])
  notifier.ping(text: text, attachments: attachment)
end

FunctionsFramework.cloud_event 'notify_train_status' do |_cloud_event|
  result = scrape
  if result[:status].include?('平常運転')
    slack_notify('平常運転です')
  else
    slack_notify("#{result[:status]}, #{result[:message]}")
    tweet
  end
end
