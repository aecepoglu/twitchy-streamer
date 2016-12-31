require "fileutils"
require "find"
require "securerandom"
require "mime/types"
require "s3_client"

class ProjectsController < ApplicationController
  protect_from_forgery except: :sync

  def index
    @projects = Project.all()
  end

  def new
    @proj = Project.new()
  end

  def create
    secret = SecureRandom.urlsafe_base64(16)

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

  def show
    @project = Project.find(params[:id])

    if params.has_key?("key")
      @key = params[:key]
    end
  end

  def dir
    s3 = MyS3Client.get

    prefix = params[:id].to_s
    resp = s3.list_objects_v2({
      bucket: MyS3Client.bucketName,
      prefix: prefix
    })

    files = []
    bucketUrl = MyS3Client.bucketUrl

    resp.contents.each do |x|
      path = x.key[(prefix.length + 1)..-1]

      if path == ""
        next
      end

      dir = File.dirname(path)

      file = {
        name: File.basename(path),
        dir: dir == "." ? nil : dir
      }

      if path[-1] != "/"
        ext = File.extname(path)[1..-1] || ""
        types = MIME::Types.type_for(ext)

        file["url"] = bucketUrl + "/" + x.key
        file["ext"] = ext
        file["type"] = types.length >= 1 ? types[0].to_s : "text/plain"
      end

      files.push(file)
    end

    render json: files
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
