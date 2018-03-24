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

  class Application
    attr_accessor :routes, :schema

    def initialize
      @routes = []
      @schema = {}
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
#  	env.each do |k,v|
#  		puts "#{k} : #{v}"
#  	end
      self.routes.each do |route_a|
        path = route_a.first
        route = route_a.last
        if env["PATH_INFO"] =~ path
          if env["REQUEST_METHOD"].downcase == route[:method]
            query_params = self.parse_query(env)
            controller_klass_name = route[:controller].capitalize + "Controller"
            controller_klass = Kernel.const_get(controller_klass_name)
            @controller = controller_klass.new
            @controller.params = {:controller => route[:controller], :action => route[:action]}
            query_params.each do |query_param|
              param = query_param.split("=")
              @controller.params[param.first.to_sym] = param.last
            end
            return @controller.send(route[:action])
          end
        end
      end

      self.not_found
    end

    # routes
    def get path, options
      @routes << [path, options.merge({:method => "get"})]
    end

    def put path, options
      @routes << [path, options.merge({:method => "put"})]
    end

    def delete path, options
      @routes << [path, options.merge({:method => "delete"})]
    end

    def post path, options
      @routes << [path, options.merge({:method => "post"})]
    end

    def setup_routes
    end

    def table name, columns
      @schema[name] = columns
    end

    def migrate
      db = SQLite3::Database.open Configuration.database
      self.schema.each do |table, columns|
        results = db.execute "SELECT name FROM sqlite_master WHERE name='#{table}'"
        if results.length == 0
          puts "Migrate #{table}"
          columns_str = columns.to_a.map {|c| "#{c.first} #{c.last}"}.join(", ");
          results = db.execute "create table #{table} (#{columns_str});"
        end
      end
    end

    def setup_schema
    end


  end

  class Controller
    attr_accessor :params

    extend ERB::DefMethod

    def render
      tmp = File.read("app/views/#{params[:controller]}/#{params[:action]}.html.erb")
      erb = ERB.new(tmp)
      erb.def_method(self.class, "render_erb()", '(ERB)')
      [200, {'content-type' => 'text/html'}, [self.render_erb]]
    end

    def redirect_to location
      [301, {'location' => "#{location}"}, []]
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
        attr_name = m.to_s.gsub(/=$/,"")
        self.attributes[attr_name]=args.first
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
