require 'rubygems'
require 'mongo'

def get_database_connection
    Mongo::Connection.new.db("radio1")
end

