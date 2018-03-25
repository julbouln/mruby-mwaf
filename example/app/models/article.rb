class Article < Mwaf::ActiveRecord::Base
  def self.table_name
    "articles"
  end
end
