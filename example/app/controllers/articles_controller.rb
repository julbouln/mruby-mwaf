
class ArticlesController < Mwaf::Controller
  def index
    @articles = Article.all
  end

  def show
    @article = Article.find(params[:id])
  end

  def edit
    if params[:id]
      @article = Article.find(params[:id])
    else
      @article = Article.new
    end
  end

  def save
    if params[:id]
      @article = Article.find(params[:id])
      # TODO UPDATE STATEMENT
    else
      @article = Article.create(:title=>params[:title], :body=>params[:body])
    end
  	redirect_to "/articles/show?id=#{@article.id}"
  end

end
