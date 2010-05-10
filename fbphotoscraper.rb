#!/usr/bin/env ruby

require 'net/http'
require 'ftools'

PHOTOS_BASE_URL = 'http://www.facebook.com/weicool?v=photos&_fb_noscript=1'
PHOTOS_PER_PAGE = 15
PHOTOS_DIR = 'photos'
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

usage_text = 'USAGE: ./fbphotoscraper.rb sid c_user xs'

if ARGV.size >= 1 && ARGV[0] == 'help'
  puts usage_text
  puts "
fbphotoscraper saves all photos you're tagged in on Facebook onto your computer.\n\n\
\
sid, c_user, and xs are values of cookies Facebook has saved to your computer.\n\n\
\
One way to find out these values is to use Firefox:\n\
1. Log in to your Facebook account.\n\
2. Under Preferences, find the menu to 'remove individual cookies'\n\
3. Look up the cookie values under the facebook.com domain\n\
You must be logged in to Facebook for this tool to work.\n\n\
\
Photos will be saved to the 'photos' directory under the current directory.
"
  exit
end

if ARGV.size < 3
  puts usage_text
  exit
end

cookies = "sid=#{ARGV[0]}; c_user=#{ARGV[1]}; xs=#{ARGV[2]}"

# Find the largest page number (so=?)
begin
  base_page = make_request(PHOTOS_BASE_URL, cookies)
  largest_page_number = base_page.scan(/(so=(\d+))+/).last.last.to_i
rescue
  puts 'FAIL: You are not logged in to Facebook; please ensure you\'ve passed in correct cookie values.'
  exit
end

counter = 0
File.makedirs('PHOTOS_DIR') unless File.directory?(PHOTOS_DIR)

num_pages_of_photos = largest_page_number / PHOTOS_PER_PAGE
(0..num_pages_of_photos).each do |i|
  page_number = i * PHOTOS_PER_PAGE
  
  # request page of photos
  photos = make_request("#{PHOTOS_BASE_URL}&so=#{page_number}", cookies)
  # get urls 
  photo_page_urls = photos.scan(/(UIPhotoGrid_TableCell"><a href="(.*?)")/).map do |url|
    url[1].gsub('amp;', '')
  end
  
  photo_page_urls.each do |photo_page_url|
    # request a page with the photo we want
    photo_page = make_request("#{photo_page_url}&_fb_noscript=1", cookies)
    photo_url = photo_page.scan(/<img src="(.*?)" id="myphoto"/)[0][0]
    
    puts_verbose photo_url
    photo = make_request(photo_url, cookies)
    File.open("#{PHOTOS_DIR}/photo_#{counter}.jpg", 'w') do |file|
      file << photo
    end
    
    counter += 1
  end
end

puts 'DONE'
