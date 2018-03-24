# fix naming issue ?
class SQLite3::SQLite::Sqlite3
  SQLite3::SQLite::SQLite3
end

# WTF?
class SQLite3::SQLite::Sqlite3Stmt
  SQLite3::SQLite::Sqlite3Stmt
end


module Mwaf

  def self.load_dirs
    if File.exists?("app/models/")
      Dir.entries("app/models/").each do |model|
        if model =~ /\.rb$/
          require "app/models/" + model
        end
      end
    end

    if File.exists?("app/controllers/")
      Dir.entries("app/controllers/").each do |controller|
        if controller =~ /\.rb$/
          require "app/controllers/" + controller
        end
      end
    end

    if File.exists?("lib/")
      Dir.entries("lib/").each do |controller|
        if controller =~ /\.rb$/
          require "lib/" + controller
        end
      end
    end

  end

  class Configuration
    def self.database
    end
  end

  # extracted from https://github.com/CicholGricenchos/Mrouter/
  module Router
    class Builder
      attr_reader :trie

      def initialize
        @trie = StaticNode.new ''
      end

      def add_route path, params
        raise 'must provide a hash or a string as params' unless params
        process_node @trie, path, params
      end

      def process_node node, path, params
        if path.nil? || path == ''
          case params
            when String
              node.params = {tag: params}
            when Hash
              node.params = params
          end
          return
        end

        head = path[0]
        case head
          when ')'
            process_node node, path[1..-1], params
          when '('
            process_node node, path[1..-1], params
            parentheses = 1
            current_index = 1
            while current_index < path.size
              case path[current_index]
                when '('
                  parentheses += 1
                when ')'
                  parentheses -= 1
              end

              if parentheses == 0
                process_node node, path[current_index+1..-1], params
                return
              end
              current_index += 1
            end
            raise "missing )"
          when ':'
            current_index = 1
            name = ''
            while current_index < path.size
              case path[current_index]
                when '/', '(', '.', ')'
                  break
                else
                  name += path[current_index]
                  current_index += 1
              end
            end

            if identical = node.children.find{|child| child.dynamic? && child.value == name}
              process_node identical, path[current_index..-1], params
            else
              new_node = node.add_child DynamicNode.new(name)
              process_node new_node, path[current_index..-1], params
            end
          else
            if identical = node.children.find{|child| child.static? && child.value == head}
              process_node identical, path[1..-1], params
            else
              new_node = node.add_child StaticNode.new(head)
              process_node new_node, path[1..-1], params
            end
        end
      end
    end

    class Compressor
      def initialize trie
        @trie = trie
      end

      def compress_node node
        child = node.children.first
        if node.static? && node.children.size == 1 && child.static? && node.params.nil?
          node.value += child.value
          node.children.replace child.children
          node.params = child.params
          compress_node node
        else
          node.children.each{|child| compress_node child}
        end
      end

      def compress!
        compress_node @trie
        @trie
      end
    end

    class Matcher
      def initialize trie
        @trie = trie
      end

      def match path
        match_path @trie, path, {}
      end

      def match_path node, path, params
        if node.static?
          if start_with?(path, node.value)
            rest = path[node.value.size..-1]
          else
            return false
          end
        elsif node.dynamic?
          current_index = 0
          value = ''
          while current_index < path.size
            case path[current_index]
              when '/', '?', '.'
                break
              else
                value += path[current_index]
            end
            current_index += 1
          end
          rest = path[current_index..-1]
          params = params.merge(node.value.to_sym => value)
        end

        if (rest == '' || rest == '/') && !node.params.nil?
          return params.merge(node.params)
        else
          if node.children.empty?
            false
          else
            node.children.each do |child|
              if matched = match_path(child, rest, params)
                return matched
              end
            end
            false
          end
        end
      end

      def start_with? origin, target
        origin[0...target.length] == target
      end
    end

    class TrieNode
      attr_accessor :children, :value, :params

      def initialize value
        @value = value
        @children = []
      end

      def leaf?
        @children.empty?
      end

      def static?; end
      def dynamic?; end

      def == another
        self.class == another.class && self.children == another.children && self.params == another.params
      end
      alias :eql? :==

      def add_child child
        @children << child
        child
      end
    end

    class StaticNode < TrieNode
      def static?
        true
      end
    end

    class DynamicNode < TrieNode
      def dynamic?
        true
      end
    end

    class Routes
      def initialize
        @compressed = false
        @builder = Builder.new
      end

      def add_route path, params
        raise "cannot add route after first match" if @compressed
        @builder.add_route path, params
      end

      def compress
        @trie = @builder.trie
        Compressor.new(@trie).compress!
        @matcher = Matcher.new(@trie)
        @compressed = true
      end

      def match path
        compress unless @compressed
        @matcher.match path
      end
    end
  end

  class Application
    attr_accessor :routes, :schema

    def initialize
      @routes = []
      @schema = {}
      @routes = Router::Routes.new
      setup_routes
      setup_schema
    end

    def parse_query(env)
      query_params = env["QUERY_STRING"].split("&")
      input_params = []
      if env["rack.input"]
        input_params = env["rack.input"].read.split("&")
      end
      query_params + input_params
    end

    def not_found
      [404, {'content-type' => 'text/plain'}, ["Not found"]]
    end

    def call(env)
      path_with_method = "#{env["REQUEST_METHOD"].downcase} #{env["PATH_INFO"]}"
      route = @routes.match path_with_method
      if route
#        puts "ROUTE: match #{path_with_method} => #{route}"
        query_params = self.parse_query(env)
        controller_klass_name = route[:controller].capitalize + "Controller"
        controller_klass = Kernel.const_get(controller_klass_name)
        @controller = controller_klass.new
        @controller.params = route
        query_params.each do |query_param|
          param = query_param.split("=")
          @controller.params[param.first.to_sym] = param.last
        end
        @controller.send(route[:action])
        unless @controller.response
          @controller.render
        end
        return @controller.response
      end
      self.not_found
    end

    # routes
    def get path, options
      self.add_route "get", path, options
    end

    def put path, options
      self.add_route "put", path, options
    end

    def delete path, options
      self.add_route "delete", path, options
    end

    def post path, options
      self.add_route "post", path, options
    end

    def table name, columns
      @schema[name] = columns
    end

    def migrate
      db = SQLite3::Database.open Configuration.database
      self.schema.each do |table, columns|
        results = db.execute "SELECT name FROM sqlite_master WHERE name='#{table}'"
        if results.length == 0
          puts "MIGRATE: #{table}"
          columns_str = columns.to_a.map {|c| "#{c.first} #{c.last}"}.join(", ");
          results = db.execute "create table #{table} (#{columns_str});"
        end
      end
    end

    def setup_routes
    end

    def setup_schema
    end

    private
    def add_route method, path, options
      path_with_method = "#{method} #{path}"
#      puts "ROUTE: add #{path_with_method} => #{options.merge({:method=>method})}"
      @routes.add_route path_with_method, options.merge({:method => method})
    end
  end

  class Controller
    attr_accessor :params, :response

    extend ERB::DefMethod

    def render(file = nil)
      unless file
        file = "app/views/#{params[:controller]}/#{params[:action]}.html.erb"
      end
      tmp = File.read(file)
      erb = ERB.new(tmp)
      erb.def_method(self.class, "render_erb()", '(ERB)')
      @response = [200, {'content-type' => 'text/html'}, [self.render_erb]]
    end

    def redirect_to location
      @response = [301, {'location' => "#{location}"}, []]
    end
  end

  class Model
    attr_accessor :attributes

    def self.database
      Mwaf::Configuration.database
    end

    def self.table_name
      self.to_s.downcase
    end

    def self.connection &block
      SQLite3::Database.new(self.database) do |db|
        block.call(db)
      end
    end

    def initialize(attributes = {})
      @attributes = attributes
    end

    def save
      if self.id
        req = []
        attributes.each do |k, v|
          req << "#{k}='#{v}'"
        end
        sql = "UPDATE #{self.class.table_name} SET #{req.join(",")} WHERE id='#{self.id}'"
        puts "SQL: #{sql}"
        self.class.connection do |db|
          db.execute sql
        end
        true
      else
        created = self.class.create(self.attributes)
        if created
          self.id = created.id
          true
        else
          false
        end
      end
    end

    def destroy
      if self.id
        sql = "DELETE FROM #{self.class.table_name} where id='#{self.id}'"
        puts "SQL: #{sql}"
        self.class.connection do |db|
          db.execute sql
        end
        true
      else
        false
      end
    end

    def self.all
      Relation.new(self)
    end

    def self.first
      self.all.first
    end

    def self.find(id)
      self.where(:id => id).first
    end

    def self.create(args)
      Relation.new(self).where(args).create
    end

    def self.where(args)
      Relation.new(self).where(args)
    end

    def method_missing(m, *args, &block)
      if m.to_s =~ /=$/
        attr_name = m.to_s.gsub(/=$/, "")
        self.attributes[attr_name] = args.first
      else
        if self.attributes[m.to_s]
          self.attributes[m.to_s]
        else
          nil
        end
      end
    end
  end

  class Relation
    attr_accessor :where, :rows

    def initialize(klass)
      @klass = klass
      @where = {}
      @rows = []
      @insert = false
    end

    def to_a
      self.exec.rows
    end

    def each &block
      self.to_a.each do |v|
        block.call v
      end
    end

    def first
      self.exec.rows.first
    end

    def create
      @insert = true
      self.exec.rows.first
    end

    def first_or_create
      first_found = self.first
      if first_found
        first_found
      else
        self.create
      end
    end

    def where(args)
      if args.class == Array
        args.each do |arg|
          @where.merge!(arg)
        end
      else
        @where.merge!(args)
      end
      self
    end

    def exec
      sql = ""
      if @insert
        sql = "INSERT INTO #{@klass.table_name} (#{@where.keys.join(",")})"
        sql += " VALUES (#{@where.values.map {|v| "'#{v}'"}.join(',')})" unless @where.empty?
      else
        sql = "SELECT * FROM #{@klass.table_name}"
        req = []
        @where.each do |argk, argv|
          req << "#{argk}='#{argv}'"
        end
        sql += " WHERE #{req.join(' AND ')}" unless @where.empty?
      end
      puts "SQL: #{sql}"

      @klass.connection do |db|
        pst = db.prepare(sql)

        pst.execute.each do |fields|
          attrs = {}
          fields.each_with_index do |field, idx|
            attrs[pst.columns[idx]] = field
          end

          @rows << @klass.new(attrs)
        end
        pst.close
        if @insert
          id = db.execute("select last_insert_rowid();")
          @rows << @klass.new(@where.merge("id" => id.flatten.first))
        end
      end
      self
    end
  end


end
