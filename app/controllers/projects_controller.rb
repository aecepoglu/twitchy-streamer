require "fileutils"
require "find"
require "securerandom"
require "rouge"

class ProjectsController < ApplicationController
  protect_from_forgery except: :sync
  helper_method :listDirectory, :rouge

  def index
    @projects = Project.all()
  end

  def new
    @proj = Project.new()
  end

  def create
    secret = SecureRandom.urlsafe_base64(16)

    puts "######## secret: " + secret

    @proj = Project.new(
      params.require(:project)
        .permit(:title)
        .merge({:password => secret})
    )

    if @proj.save() then
      redirect_to(action: "show", id: @proj.id, key: secret)
    else
      render "new"
    end
  end

  def listDirectory(projId)
    Dir.chdir("/tmp/filestream/#{projId}") do
      Find.find("./") do |path|
        if path != "./"
          list = path[2..-1].split("/")
  
          obj = {
            :name => list[-1],
            :level => list.length,
            :path => list.join("/"),
            :isDir => FileTest.directory?(path)
          }

          if (list.length > 1)
            obj[:dir] = list[0..-2].join("/")
          end
  
          yield obj
        end
      end
    end
  end

  def rouge(projId, filepath)
    text = File.read(File.join("/tmp/filestream", projId.to_s, filepath))

    formatter = Rouge::Formatters::HTML.new

    lexer = Rouge::Lexer.guess({:filename => filepath})

    formatter.format(lexer.lex(text))
  end

  def show
    @project = Project.find(params[:id])

    if params.has_key?("key")
      @key = params[:key]
    end

    if params.has_key?("file")
      @currentFile = params[:file]
      @pageTitle = @currentFile
    end

    @showFiles = true
  end

  def respondNotFound
    render plain: "no such record", status: 404
    return
  end

  def sync
    begin
      project = Project.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      return respondNotFound
    end

    if not project.authenticate(params[:key])
      logger.info "unauth access to project-#{params[:project_id]} by #{request.remote_ip}"
      return respondNotFound
    end

    params.each { |x,y| puts(x + " : " + y.to_s) }

    if not params.has_key?(:file) or not params.has_key?(:dir)
      render plain: "file and dir params required", status: 400
      return
    elsif params[:dir].include? ".."
      render plain: "bad dir value", status: 400
      return
    end

    file = params[:file]
    targetDir = File.join(
      "/tmp/filestream",
      project.id.to_s,
      params[:dir]
    )
     
    FileUtils.mkdir_p(targetDir)
    FileUtils.mv(file.tempfile.path, File.join(targetDir, file.original_filename))

    render plain: "ok"
  end
end
