require './target.rb'
require './listing.rb'

class ListingTargetFilter

    def initialize(targets)
        @target_search_fields = Array.new()
        targets.each() { |target| @target_search_fields.push(target.search_field) }
    end

    def is_target_listing(listing)
        return !@target_search_fields.index(listing.dj).nil?
    end

end
