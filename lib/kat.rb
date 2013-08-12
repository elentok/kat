# TODO: Lookup advanced search for language and platform values

require 'nokogiri'
require 'open-uri'

class Kat
  KAT_URL = 'http://kickass.to'
  EMPTY_URL = 'new'
  SEARCH_URL = 'usearch'
  ADVANCED_URL = "#{KAT_URL}/torrents/search/advanced/"

  STRING_FIELDS = [ :category, :seeds, :user, :age, :files, :imdb, :season, :episode ]

  # The names of these fields are transposed for ease of use
  SELECT_FIELDS = [ { :name => :language, :id => :lang_id }, { :name => :platform, :id => :platform_id } ]

  # If these are set to anything but nil or false, they're turned on in the query
  SWITCH_FIELDS = [ :safe, :verified ]

  SORT_FIELDS   = %w(size files_count time_add seeders leechers)

  # The number of pages of results
  attr_reader :pages

  # Any error in searching is stored here
  attr_reader :error

  #
  # Create a new +Kat+ object to search Kickass Torrents.
  # The search_term can be nil, a string/symbol, or an array of strings/symbols.
  # Valid options are in STRING_FIELDS, SELECT_FIELDS or SWITCH_FIELDS.
  #
  def initialize search_term = nil, opts = {}
    @search_term = []
    @options = {}

    self.query = search_term
    self.options = opts
  end

  #
  # Kat.search will do a quick search and return the results
  #
  def self.search search_term
    self.new(search_term).search
  end

  #
  # Generate a query string from the stored options, supplying an optional page number
  #
  def query_str page = 0
    str = [ SEARCH_URL, @query.join(' ').gsub(/[^a-z0-9: _-]/i, '') ]
    str = [ EMPTY_URL ] if str[1].empty?
    str << page + 1 if page > 0
    str << if SORT_FIELDS.include? @options[:sort].to_s
      "?field=#{options[:sort].to_s}&sorder=#{options[:asc] ? 'asc' : 'desc'}"
    else
      ''    # ensure a trailing slash after the search terms or page number
    end
    str.join '/'
  end

  #
  # Change the search term, triggering a query rebuild and clearing past results.
  #
  # Raises ArgumentError if search_term is not a String, Symbol or Array
  #
  def query= search_term
    @search_term = case search_term
      when nil then []
      when String, Symbol then [ search_term ]
      when Array then search_term.flatten.select {|el| [ String, Symbol ].include? el.class }
      else raise ArgumentError, "search_term must be a String, Symbol or Array. #{search_term.inspect} given."
    end
    build_query
  end

  #
  # Get a copy of the search options hash
  #
  def options
    @options.dup
  end

  #
  # Change search options with a hash, triggering a query string rebuild and
  # clearing past results.
  #
  # Raises ArgumentError if opts is not a Hash
  #
  def options= opts
    raise ArgumentError, "opts must be a Hash. #{opts.inspect} given." unless opts.is_a? Hash
    @options.merge! opts
    build_query
  end

  #
  # Perform the search, supplying an optional page number to search on. Returns
  # a result set limited to the 25 results Kickass Torrents returns itself. Will
  # cache results for subsequent calls of search with the same query string.
  #
  def search page = 0
    unless @results[page] or (@pages > -1 and page >= @pages)
      begin
        doc = Nokogiri::HTML(open("#{KAT_URL}/#{URI::encode(query_str page)}"))
        @results[page] = doc.css('td.torrentnameCell').map do |node|
          { :title    => node.css('a.normalgrey').text,
            :magnet   => node.css('a.imagnet').first.attributes['href'].value,
            :download => node.css('a.idownload').last.attributes['href'].value,
            :size     => (node = node.next_element).text,
            :files    => (node = node.next_element).text.to_i,
            :age      => (node = node.next_element).text,
            :seeds    => (node = node.next_element).text.to_i,
            :leeches  => (node = node.next_element).text.to_i }
        end

        # If we haven't previously performed a search with this query string, get the
        # number of pages from the pagination bar at the bottom of the results page.
        @pages = doc.css('div.pages > a').last.text.to_i if @pages < 0

        # If there was no pagination bar and the previous statement didn't trigger
        # a NoMethodError, there are results but only 1 page worth.
        @pages = 1 if @pages <= 0
      rescue NoMethodError
        # The results page had no pagination bar, but did return some results.
        @pages = 1
      rescue => e
        # No result throws a 404 error.
        @pages = 0 if e.class == OpenURI::HTTPError and e.message['404 Not Found']
        @error = { :error => e, :query => query_str(page) }
      end
    end

    results[page]
  end

  #
  # For message chaining
  #
  def do_search page = 0
    search page
    self
  end

  #
  # Get a copy of the results
  #
  def results
    @results.dup
  end

  #
  # If the method_sym or its plural is a field name in the results list, this will tell us
  # if we can fetch the list of values. It'll only happen after a successful search.
  #
  def respond_to? method_sym, include_private = false
    if not (@results.empty? or @results.last.empty?) and
           (@results.last.first[method_sym] or @results.last.first[method_sym.to_s.chop.to_sym])
      return true
    end
    super
  end

private

  #
  # Clear out the query and rebuild it from the various stored options. Also clears out the
  # results set and sets pages back to -1
  #
  def build_query
    @query = @search_term.dup
    @pages = -1
    @results = []

    @query << "\"#{@options[:exact]}\"" if @options[:exact]
    @query << @options[:or].join(' OR ') unless @options[:or].nil? or @options[:or].empty?
    @query += @options[:without].map {|s| "-#{s}" } if @options[:without]

    STRING_FIELDS.each {|f| @query << "#{f}:#{@options[f]}" if @options[f] }
    SELECT_FIELDS.each {|f| @query << "#{f[:id]}:#{@options[f[:name]]}" if @options[f[:name]].to_i > 0 }
    SWITCH_FIELDS.each {|f| @query << "#{f}:1" if @options[f] }
  end

  #
  # If method_sym or its plural form is a field name in the results list, fetch the list of values.
  # Can only happen after a successful search.
  #
  def method_missing method_sym, *arguments, &block
    # Don't need no fancy schmancy pluralizing method. Just try chopping off the 's'.
    m = method_sym.to_s.chop.to_sym
    if not (@results.empty? or @results.last.empty?) and
           (@results.last.first[method_sym] or @results.last.first[m])
      return @results.compact.map {|rs| rs.map {|r| r[method_sym] || r[m] } }.flatten
    end
    super
  end

end
