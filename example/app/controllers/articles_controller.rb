
class ArticlesController < Mwaf::Controller
  def index
    @articles = Article.all
  	render
  end

  def show
    @article = Article.find(params[:id])
  	render
  end

  def edit
    puts params
    if params[:id]
      @article = Article.find(params[:id])
      puts @article.id
    else
      @article = Article.new
    end
  	render
  end

  def save
    if params[:id]
      @article = Article.find(params[:id])
      # TODO UPDATE STATEMENT
    else
      @article = Article.create(:title=>params[:title], :body=>params[:body])
    end
    puts @article.attributes
  	redirect_to "/articles/show?id=#{@article.id}"
  end

end
