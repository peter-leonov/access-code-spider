#!/usr/bin/env ruby
require 'fileutils'
require 'anemone'
require 'logger/colors'

log = Logger.new(STDOUT)
log.formatter = proc { |s,d,p,m| "#{m}\n" }

HTTP_ROOT = 'http://echo.msk.ru'
PATH_START = HTTP_ROOT + '/programs/code/archive/1.html'
PATH_FILTER = %r{/programs/code/archive/}
PATH_BLACKLIST = %r{comments|xml}
DELAY = 3.0 # seconds
MAX_TIME = 15 # seconds waiting for file

module TheDate
  NAME_TO_N = {
    'января' => '01',
    'февраля' => '02',
    'марта' => '03',
    'апреля' => '04',
    'мая' => '05',
    'июня' => '06',
    'июля' => '07',
    'августа' => '08',
    'сентября' => '09',
    'октября' => '10',
    'ноября' => '11',
    'декабря' => '12',
  }
  
  def self.parse date
    m = /^(\d{2}) (\S+) (\d{4}), \d+:\d+$/.match(date)
    unless m
      raise "failed to parse date: #{date}"
    end
    unless month = NAME_TO_N[m[2]]
      raise "failed to parse month: '#{month}' in '#{date}'"
    end
    "#{m[3]}-#{month}-#{m[1]}"
  end
end


FileUtils.mkdir_p 'files'
Dir.chdir 'files'


$done = Dir['*.mp3'].map { |name| name[/^[^.]+/] } .inject({}) { |c,v| c[v] = true; c }

Anemone.crawl(PATH_START) do |anemone|
  # anemone.storage = Anemone::Storage.SQLite3
  
  anemone.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/33.0.#{rand(1750)}.152 Safari/537.36"
  anemone.delay = DELAY
  anemone.threads = 1
  
  anemone.on_every_page do |page|
    puts page.url
    begin
      page.doc.css('.topBlock.lastBroadcast .list .column').each do |column|
        date = TheDate.parse(column.css('.date').text.strip)
        
        anchors = column.css('.icInfo.icDownload')
        if anchors.size == 0
          log.warn "none links found for date #{date}"
          next
        end
        
        anchors.each_with_index do |a, i|
          url = a['href'].to_s
          
          unless /mp3/ =~ url
            log.warn "url does not look like mp3 link: #{url}"
          end
          
          fname = i == 0 ? date : "#{date}-#{i}"
          if $done[fname]
            log.debug "  done already: #{fname}"
            next
          end

          log.info "  #{fname} from #{url}"
          unless system("curl", "-s", "-L", "--retry", "10", "-m", "#{MAX_TIME}", "-o", "#{fname}-part.mp3", url)
            log.error "failed to download file"
            next
          end
          File.rename("#{fname}-part.mp3", "#{fname}.mp3")

          sleep DELAY
        end
      end
    rescue => e
      log.error e.message
    ensure
      sleep DELAY
    end
  end
  
  anemone.focus_crawl do |page|
    # puts page.links.map &:path
    page.links.select do |link|
      link.path =~ PATH_FILTER and
      link.path !~ PATH_BLACKLIST
    end
  end
end