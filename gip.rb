class Gip

    def get_listings()
        lines = get_listings_data()
        results = Array.new()
        lines.each_line do |line|
            listing = parse_line(line)
            if !listing.nil?
                results.push(listing)
            end
        end
        results
    end

    def get_listings_by_id(listing_id)
        lines = get_listings_data()
        results = Array.new()
        lines.each_line do |line|
            if /^#{listing_id}:\s/.match(line)
                match = /^(\d+):\s+(.*)\s+-\s+(.+), (BBC [^,]+),.*hours ago - (.+)$/.match(line)
                if !match.nil?
                    puts "MATCH: ID:   " + listing_id
                    puts "       DJ:   " + match[2]
                    puts "       SHRT: " + match[3]
                    puts "       STAT: " + match[4]
                    puts "       LONG: " + match[5]
                    result = Listing.new()
                    result.id = match[1]
                    result.dj = match[2]
                    result.short_description = match[3]
                    result.station = match[4]
                    result.long_description = match[5]
                    results.push(result)
                end
                puts "GOT MATCH:"
                puts line
            end
        end
        results
    end

    def download_listing(listing, level)
        puts "Downloading id: " + listing.id.to_s() + ", quality: " + level
        output = download_file(listing.id, level)
    end

private

    def download_file(id, level)
        puts ">> " + '../get_iplayer ' + id + ' --get --mode=flashaac' + level + ' --force'
        output = `../get_iplayer #{id} --get --mode=flashaac#{level} --force 2>&1`
    end

    def get_listings_data()
        lines = `../get_iplayer --long --type=radio 2>&1`
    end

    def parse_line(line)
        result = nil
        match = /^(\d+):\s+(.*)\s+-\s+(.+), (BBC [^,]+),.*hours ago - (.+)$/.match(line)
        if !match.nil?
            result = Listing.new()
            result.id = match[1]
            result.dj = match[2]
            result.short_description = match[3]
            result.station = match[4]
            result.long_description = match[5]
        end
        result
    end

end

