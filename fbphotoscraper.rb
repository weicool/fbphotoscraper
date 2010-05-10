#!/usr/bin/env ruby

require 'net/http'
require 'ftools'

$verbose = true;

def make_request(url, cookies = '', redirect_depth = 10)
  raise "FAIL: too many redirects" if redirect_depth == 0
  
  headers = {
    'User-Agent' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.6; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3',
    'Cookie' => cookies
  }
  url = URI.parse(url)
  response = Net::HTTP.start(url.host, url.port) do |http|
    http.get(url.request_uri, headers)
  end
  
  # follow redirects
  case response
  when Net::HTTPSuccess     then response
  when Net::HTTPRedirection then make_request(response['location'], cookies, redirect_depth - 1)
  else
    response.error!
  end
  
  response.body
end

def puts_verbose(s)
  puts s if $verbose
end

usage_text = 'USAGE: ./fbphotoscraper.rb username sid c_user xs'

if ARGV.size >= 1 && ARGV[0] == 'help'
  puts usage_text
  puts "
fbphotoscraper saves all photos you're tagged in on Facebook onto your computer.\n\n\
\
username is your Facebook username\n\
\
sid, c_user, and xs are values of cookies Facebook has saved to your computer.\n\n\
\
One way to find out these values is to use Firefox:\n\
1. Log in to your Facebook account.\n\
2. Under Firefox's Preferences, find the menu to 'remove individual cookies'.\n\
3. Look up the cookie values under the facebook.com domain.\n\
You must be logged in to Facebook for this tool to work.\n\n\
\
Photos will be saved to the 'photos' directory under the current directory.
"
  exit
end

if ARGV.size < 4
  puts usage_text
  exit
end

photos_base_url = "http://www.facebook.com/#{ARGV[0]}?v=photos&_fb_noscript=1"
photos_per_page = 15
photos_dir = 'photos'

cookies = "sid=#{ARGV[1]}; c_user=#{ARGV[2]}; xs=#{ARGV[3]}"

# Find the largest page number (so=?)
begin
  base_page = make_request(photos_base_url, cookies)
  largest_page_number = base_page.scan(/(so=(\d+))+/).last.last.to_i
rescue
  puts 'FAIL: You are not logged in to Facebook; please ensure you\'ve passed in correct cookie values.'
  exit
end

counter = 0
File.makedirs(photos_dir) unless File.directory?(photos_dir)

num_pages_of_photos = largest_page_number / photos_per_page
(0..num_pages_of_photos).each do |i|
  page_number = i * photos_per_page
  
  # request page of photos
  photos = make_request("#{photos_base_url}&so=#{page_number}", cookies)
  # get urls 
  photo_page_urls = photos.scan(/(UIPhotoGrid_TableCell"><a href="(.*?)")/).map do |url|
    url[1].gsub('amp;', '')
  end
  
  photo_page_urls.each do |photo_page_url|
    # request a page with the photo we want
    photo_page = make_request("#{photo_page_url}&_fb_noscript=1", cookies)
    photo_url = photo_page.scan(/<img src="(.*?)" id="myphoto"/)[0][0]
    # hack to deal with broken regex -- might consume too many characters
    index_of_quote = photo_url.index('"')
    photo_url = photo_url[0...index_of_quote] if index_of_quote
    
    puts_verbose photo_url
    photo = make_request(photo_url, cookies)
    File.open("#{photos_dir}/photo_#{counter}.jpg", 'w') do |file|
      file << photo
    end
    
    counter += 1
  end
end

puts 'DONE'
