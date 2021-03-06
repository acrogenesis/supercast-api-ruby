# frozen_string_literal: true

module Supercast
  class DataList < DataObject
    include Enumerable
    include Supercast::Operations::List
    include Supercast::Operations::Request
    include Supercast::Operations::Create

    OBJECT_NAME = 'list'

    # This accessor allows a `DataList` to inherit various filters that were
    # given to a predecessor. This allows for things like consistent limits,
    # expansions, and predicates as a user pages through resources.
    attr_accessor :filters

    # An empty list object. This is returned from +next+ when we know that
    # there isn't a next page in order to replicate the behavior of the API
    # when it attempts to return a page beyond the last.
    def self.empty_list(opts = {})
      DataList.construct_from({ data: [] }, opts)
    end

    def initialize(*args)
      super
      self.filters = {}
    end

    def [](key)
      case key
      when String, Symbol
        super
      else
        raise ArgumentError,
              "You tried to access the #{key.inspect} index, but DataList " \
              'types only support String keys. (HINT: List calls return an ' \
              "object with a 'data' (which is the data array). You likely " \
              "want to call #data[#{key.inspect}])"
      end
    end

    # Iterates through each resource in the page represented by the current
    # `DataList`.
    #
    # Note that this method makes no effort to fetch a new page when it gets to
    # the end of the current page's resources. See also +auto_paging_each+.
    def each(&blk)
      data.each(&blk)
    end

    # Iterates through each resource in all pages, making additional fetches to
    # the API as necessary.
    #
    # Note that this method will make as many API calls as necessary to fetch
    # all resources. For more granular control, please see +each+ and
    # +next_page+.
    def auto_paging_each(&blk)
      return enum_for(:auto_paging_each) unless block_given?

      page = self

      loop do
        page.each(&blk)
        page = page.next_page
        break if page.empty?
      end
    end

    # Returns true if the page object contains no elements.
    def empty?
      data.empty?
    end

    def retrieve(id, opts = {})
      id, retrieve_params = Util.normalize_id(id)
      resp, opts = request(:get, "#{resource_url}/#{CGI.escape(id)}",
                           retrieve_params, opts)
      Util.convert_to_supercast_object(resp.data, opts)
    end

    # Fetches the next page in the resource list (if there is one).
    #
    # This method will try to respect the limit of the current page. If none
    # was given, the default limit will be fetched again.
    def next_page(params = {}, opts = {})
      return self.class.empty_list(opts) unless defined?(page) && defined?(per_page) && defined?(total) && page * per_page < total

      params = filters.merge(page: page + 1).merge(params)

      list(params, opts)
    end

    # Fetches the previous page in the resource list (if there is one).
    #
    # This method will try to respect the limit of the current page. If none
    # was given, the default limit will be fetched again.
    def previous_page(params = {}, opts = {})
      return self.class.empty_list(opts) unless page && page > 1

      params = filters.merge(page: page - 1).merge(params)

      list(params, opts)
    end

    def resource_url
      url ||
        raise(ArgumentError, "List object does not contain a 'url' field.")
    end
  end
end
