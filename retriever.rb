require 'fileutils'
require './target.rb'
require './gip.rb'
require './listing_target_filter.rb'

class Retriever

    def initialize()
        @gip = Gip.new()
    end

    def retrieve(level)
        if ARGV.count > 0 then
            retrieve_by_id(ARGV[0], level)
        else
            retrieve_by_search(level)
        end
    end

private

    def retrieve_by_id(listing_id, level)
        puts "Retrieving by id: " + listing_id
        listings = @gip.get_listings_by_id(listing_id)
        #db_listings = get_current_listings(listings)
        handle_listings(listings, level)
    end

    def retrieve_by_search(level)
        puts "Retrieving via search"
        targetedListings = get_targeted_listings();
        #listings = get_current_listings(targetedListings)
        handle_listings(targetedListings, level)
    end

#    def retrieve_listings(listings, level)
#        listings.each do |listing|
#          puts listing.to_s()
#        end
#        #download_listings(listings, level)
#        #convert_to_mp3()
#    end
 
    def convert_to_mp3()
        puts "  Converting m4a files to mp3, adding metadata tags at the same time"
        listings = @repository.get_listings({ "downloaded" => true, "converted_to_mp3" => false })
        listings.each do |listing|
            puts "    Converting m4a to mp3"
            puts "      #{listing.converted_to_mp3}"

            artist = listing.dj;
            title = listing.date.strftime("%Y-%m-%d") + " - " + listing.dj + " - " + listing.short_description;
            album = "BBC - " + listing.dj;
            genre = "Dance";

            # Essential mixes
            if /Essential.Mix/.match(listing.dj) then
                artist = listing.short_description
                album = "BBC - Essential Mix"
                title = listing.date.strftime("%Y-%m-%d") + " - Essential Mix: " + listing.short_description
            end

            # set mp3 attributes in database
            listing.mp3_artist = artist
            listing.mp3_album = album
            listing.mp3_title = title
            listing.mp3_genre = genre

            # create the album directory if necessary
            album_directory = "./converted";
            if !File.exists?(album_directory) || !File.directory?(album_directory)
                puts "    Creating directory: " + album_directory
                FileUtils.mkdir album_directory
                if !File.exists?(album_directory) || !File.directory?(album_directory)
                    puts "      ERROR: could not create directory"
                    return
                end
            end

            # worked out the metadata, so convert to mp3
            listing.mp3_file = listing.file_name.sub(/downloaded/, "converted")
            listing.mp3_file = listing.mp3_file.sub(/\.m4a$/, ".mp3")
            puts "      Converting to mp3_file: " + listing.mp3_file
            `ffmpeg -i "#{listing.file_name}" -ab 128k -metadata artist="#{artist}" -metadata title="#{title}" -metadata album="#{album}" -metadata genre="#{genre}" "#{listing.mp3_file}"`

            # update the database record if successful
            if File.exists? listing.mp3_file
                puts "        Converted file, updating database"
                listing.converted_to_mp3 = true
                @repository.set_listing(listing)
            end
        end
    end

    #def get_current_listings(current_listings)
        #puts "  Looking up listings in db"
        #consolidated_listings = Array.new
        #current_listings.each() do |current_listing|
        #    db_listing = @repository.get_listing(
        #        current_listing.dj,
        #        current_listing.station,
        #        current_listing.short_description,
        #        current_listing.long_description)
        #    
        #    consolidated_listing = current_listing 
        #    if !db_listing.nil?
        #        db_listing.id = current_listing.id
        #        consolidated_listing = db_listing
        #    else
        #        @repository.add_new_listing(current_listing)
        #    end
        #    consolidated_listings.push(consolidated_listing)
        #end
        #consolidated_listings
    #end

    def get_targeted_listings()
        listings = @gip.get_listings()
        filter = ListingTargetFilter.new(get_targets())
        filtered_listings = Array.new()
        listings.each() do |listing|
            if filter.is_target_listing(listing)
                filtered_listings.push(listing)
            end
        end
        filtered_listings
    end

    def handle_listings(listings, level)
        listings.each() do |listing|
          handle_listing(listing, level)
          puts
        end
    end


    def handle_listing(listing, level)
        puts "Checking listing: #{listing}"

        ensure_listing_downloaded(listing, level)
        if listing.raw_file_name.nil? || listing.date.nil? || listing.hash.nil?
          puts "Download failed, stopping"
          return
        end

        puts "  hash:          #{listing.hash}"
        puts "  date:          #{listing.date}"
        puts "  raw_file_name: #{listing.raw_file_name}"

        if File.readlines('./data/download-completed.txt').grep(/#{listing.hash}/).size > 0
          puts "File processing completed for #{listing.hash}, stopping"
          return
        end

        puts "    File: raw_file_path:    #{listing.raw_file_name}"
        puts "    File: staged_file_path: #{listing.staged_file_path}"
        puts "    File: mp3_file_path:    #{listing.mp3_file_path}"
        puts "    File: nas_file_path:    #{listing.nas_file_path}"
        
        ensure_listing_converted_to_mp3(listing)
        ensure_listing_moved_to_nas_drive(listing)
    end

    def ensure_listing_downloaded(listing, level)
      listing_lookup_string = listing.lookup_string

      File.open('./data/download-details.txt', 'r') do |file_handle|
        file_handle.each_line do |line|
          lookup, hash, date, raw_file_name = line.split('|')
          if !lookup.nil? && !hash.nil? && !raw_file_name.nil? && !date.nil? && lookup == listing_lookup_string
            listing.hash = hash
            listing.date = date
            listing.raw_file_name = raw_file_name
          end
        end
      end

      if !listing.hash.nil? && !listing.raw_file_name.nil?
        puts "Already downloaded: #{listing.hash}"
        return
      end

      puts "Downloading: " + listing.to_s()

      download_output = @gip.download_listing(listing, level)

      if !download_output.nil? 
        download_output.split(/\n/).each() do |line|
          line_match = /^INFO: Recorded .*\/([^\/]*)\s*$/.match(line)
          if !line_match.nil?
            listing.raw_file_name = "./" + line_match[1]
            hash_match = /_([^_]+)_default.m4a$/.match(listing.raw_file_name)
            if !hash_match.nil?
              listing.hash = hash_match[1]
            end
          end

          line_match = /©nam .+(\d{2}) (\d{2}) (\d{4})\s*$/.match(line)
          if !line_match.nil?
            listing.date = line_match[3].sub(/^0*/,"") + "-" + line_match[2].sub(/^0*/,"").rjust(2, "0") + "-" + line_match[1].sub(/^0*/,"").rjust(2, "0")
          end
        end
      end

      if listing.raw_file_name.nil? || listing.date.nil? || listing.hash.nil?
        puts "FAILED"
      else
        puts "SUCCEEDED"
        puts "Writing to ./data/download-details.txt"
        open('./data/download-details.txt', 'a') do |f|
          f.puts listing.details_string
        end
      end

    end


    def ensure_listing_converted_to_mp3(listing)
    end

    def ensure_listing_moved_to_nas_drive(listing)
    end

    def get_file_name(listing)
        d = listing.date
        dj = sanitise_string(listing.dj).sub(/^BBC_Radio_1s_/, "").sub(/\s-\s\S+day/, "")
        description = sanitise_string(listing.short_description)
        f = "./downloaded/" +
            d.year.to_s() + "-" +
            d.month.to_s().rjust(2, "0") + "-" +
            d.day.to_s().rjust(2, "0") + "-" +
            dj
        if !/\D+/.match(description).nil?
            f = f + "-" + description
        end
        f = f + ".m4a"
    end

    def sanitise_string(s)
        s = s.gsub(/['.,"!^#£$?\\\/]/, "")
        s = s.gsub(/[&]/, "and")
        s.gsub(/\s/, "_")
    end

    def get_targets()
        results = Array.new()
        File.open('./data/targets.txt', 'r') do |file_handle|
          file_handle.each_line do |line|
            pattern, name = line.split('|')
            if !name.nil? && !pattern.nil?
              pattern = pattern.chomp
              puts "Target: #{pattern} => #{name}"
              results.push(Target.new(name, pattern));
            end
          end
        end
        puts
        results
    end

end

