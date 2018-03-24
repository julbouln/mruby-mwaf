Mwaf.load_dirs

class Mwaf::Configuration
  def self.database
    "blog.db"
  end
end

class BlogApplication < Mwaf::Application
  def setup_routes
    get "/articles/show(/:id)", {:controller => "articles", :action => "show"}
    get "/articles/edit(/:id)", {:controller => "articles", :action => "edit"}
    post "/articles/save", {:controller => "articles", :action => "save"}
    get "/articles", {:controller => "articles", :action => "index"}
  end

  def setup_schema
    table "articles", {:id=>"integer primary key", :title => "varchar(255)", :body => "text"}
  end

end
