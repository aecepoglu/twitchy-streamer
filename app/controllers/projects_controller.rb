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

  def sync
    begin
      project = Project.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render plain: "no such record", status: 404
      return
    end

    if not project.authenticate(params[:key])
      logger.info "unauth access to project-#{params[:id]} by #{request.remote_ip}"
      render plain: "no such record", status: 404
      return
    end

    if not params.has_key?(:file) or not params.has_key?(:dir)
      render plain: "file and dir params required", status: 400
      return
    elsif params[:dir].include? ".."
      render plain: "you may not access other folders", status: 403
      return
    end

    s3 = MyS3Client.get
    file = params[:file]

    begin
      File.open file.tempfile.path do |fp|
        s3.put_object({
          acl: "public-read",
          bucket: MyS3Client.bucketName,
          key: File.join(project.id.to_s, params[:dir], file.original_filename),
          body: fp
        })
      end
    rescue => e
      logger.error e
      render plain: "aws upload error", status: 500
      return
    end

    render plain: "ok"
  end
end
