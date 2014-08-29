module Aweplug
  module Helpers
    module Video
      class VideoBase

        def initialize(video, site)
          @site = site
          if site.cache.nil?
            site.send('cache=', Aweplug::Cache::YamlFileCache.new)
          end
          @cache = site.cache
          @video = video
        end

        # Create the basic methods
        [:detail_url, :height, :id, :thumb_url, :title, :width].each do |attr|
          define_method attr.to_s do
            @video[attr.to_s] || ''
          end
        end

        # Create date methods
        [:modified_date, :upload_date, :update_date].each do |attr|
          define_method attr.to_s do
            pretty_date(@video[attr.to_s])
          end

          define_method "#{attr.to_s}_iso8601" do
            DateTime.parse(@video[attr.to_s]).iso8601
          end
        end
        
        def description
          d = @video["description"]
          out = ""
          if d
            i = 0
            max_length = 150
            d.scan(/[^\.!?]+[\.!?]/).map(&:strip).each do |s|
              i += s.length
              if i > max_length
                break
              else
                out += s
              end
            end
            # Deal with the case that the description has no sentence end in it
            out = out.empty? ? d : out
          end
          out
        end

        def normalized_author
          normalized_cast[0]
        end

        def cast
          raise NotImplementedError
        end

        def normalized_cast
          if @ncast.nil?
            @ncast = []
            unless cast.empty?
              searchisko = Aweplug::Helpers::Searchisko.new({:base_url => @site.dcp_base_url, 
                                                :authenticate => true, 
                                                :searchisko_username => ENV['dcp_user'], 
                                                :searchisko_password => ENV['dcp_password'], 
                                                :cache => @site.cache,
                                                :logger => @site.log_faraday,
                                                :searchisko_warnings => @site.searchisko_warnings})
              cast.each do |c|
                searchisko.normalize("contributor_profile_by_#{provider}_username", c['username']) do |contributor|
                  if !contributor['sys_contributor'].nil?
                    @ncast << add_social_links(contributor['contributor_profile'])
                  elsif !c['display_name'].nil? && !c['display_name'].strip.empty?
                    @ncast << OpenStruct.new({:sys_title => c['display_name']})
                  end
                end
              end 
            end
          end
          @ncast
        end

        def tags
          r = []
          if @video['tags'].is_a? Hash
            @video['tags']['tag'].inject([]) do |result, element|
              r << element['normalized']
            end
          end
          r
        end

        def searchisko_payload
          unless @fetch_failed
            author = cast[0]
            {
              :sys_title => title,
              :sys_description => description,
              :sys_url_view => "#{@site.base_url}/video/vimeo/#{id}",
              :author => author.nil? ? nil : author['username'],
              :contributors => cast.empty? ? nil : cast.collect {|c| c['username']},
              :sys_created => upload_date_iso8601,
              :sys_last_activity_date => modified_date_iso8601,
              :duration => duration_in_seconds,
              :thumbnail => thumb_url,
              :tags => tags
            }.reject{ |k,v| v.nil? }
          end
        end

        def contributor_exclude
          contributor_exclude = Pathname.new(@site.dir).join("_config").join("searchisko_contributor_exclude.yml")
          if contributor_exclude.exist?
            yaml = YAML.load_file(contributor_exclude)
            return yaml['vimeo'] unless yaml['vimeo'].nil?
          end
          {}
        end

        def duration_time
          Time.at(Integer(@video["duration"])).utc
        end


        def duration
          duration_time.strftime("%T")
        end
        
        def duration_in_seconds
          duration_time.to_i
          #a = duration_time.split(":").reverse
          #(a.length > 0 ? a[0].to_i : 0) + (a.length > 1 ? a[1].to_i * 60 : 0) + (a.length > 2 ? a[2].to_i * 60 : 0)
        end

        def duration_iso8601
          duration_time.strftime("PT%HH%MM%SS")
        end

        def pretty_date(date_str)
          date = DateTime.parse(date_str)
          a = (Time.now-date.to_time).to_i

          case a
          when 0 then 'just now'
          when 1 then 'a second ago'
          when 2..59 then a.to_s+' seconds ago' 
          when 60..119 then 'a minute ago' #120 = 2 minutes
          when 120..3540 then (a/60).to_i.to_s+' minutes ago'
          when 3541..7100 then 'an hour ago' # 3600 = 1 hour
          when 7101..82800 then ((a+99)/3600).to_i.to_s+' hours ago' 
          when 82801..172000 then 'a day ago' # 86400 = 1 day
          when 172001..518400 then ((a+800)/(60*60*24)).to_i.to_s+' days ago'
          when 518400..1036800 then 'a week ago'
          when 1036800..4147200 then ((a+180000)/(60*60*24*7)).to_i.to_s+' weeks ago'
          else date.strftime("%F")
          end
        end

      end
    end
  end
end

