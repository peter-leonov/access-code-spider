#!/usr/bin/env ruby
require 'fileutils'
require 'anemone'
require 'logger/colors'

log = Logger.new(STDOUT)
log.formatter = proc { |s,d,p,m| "#{s}: #{m}\n" }

HTTP_ROOT = 'http://echo.msk.ru'
PATH_START = HTTP_ROOT + '/programs/code/'
PATH_FILTER = %r{/programs/code/archive/}
PATH_BLACKLIST = %r{comments|xml}
DELAY = 2.0

FileUtils.mkdir_p 'code'
Dir.chdir 'code'

remap = {
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

loaded = Dir['*.mp3'].map do |name|
  m = /^(\S+) (\S+) (\S+)\./.match name
  unless m
    log.error "FAILED TO PARSE DATE: #{name}"
    next
  end
  unless month = remap[m[2]]
    log.error "FAILED TO PARSE MONTH: #{month}"
    next
  end
  File.rename name, "#{m[3]}-#{month}-#{m[1]}.mp3"
end

exit 0

Anemone.crawl(PATH_START) do |anemone|
  # anemone.storage = Anemone::Storage.SQLite3
  
  anemone.delay = DELAY
  anemone.threads = 1
  
  anemone.on_every_page do |page|
    puts page.url
    begin
      page.doc.css('.topBlock.lastBroadcast .list .column').each do |column|
        url = column.css('.icInfo.icDownload').attr('href').to_s
        
        date = column.css('.date span').text.to_s[/.+(?=,)/]
        log.error "FAILED TO PARSE DATE: #{name}"
        
        puts "#{date} from #{url}"
        system("curl", "-L", "-o", "#{date}.mp3", url)
        
        sleep DELAY
      end
    rescue => e
      puts "failed #{page.url}: #{e.message}"
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