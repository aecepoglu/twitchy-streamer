require "securerandom"
require "mime/types"
require "s3_client"

class MyError < StandardError
  attr_reader :object

  def initialize(object)
    @object = object
  end
end

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
      redirect_to(action: "show", id: @proj.hashid, key: secret)
    else
      render "new"
    end
  end

  def show
    @project = Project.find_by_hashid(params[:id])

    if params.has_key?("key")
      @key = params[:key]
    end
  end

  def dir
    resp = nil

    begin
      s3 = MyS3Client.get

      prefix = params[:id].to_s
      resp = s3.list_objects_v2({
        bucket: MyS3Client.bucketName,
        prefix: prefix
      })
    rescue Aws::Errors::MissingRegionError,
        Aws::Errors::MissingCredentialsError,
        Aws::Errors::ServiceError => e
      logger.error e
      render plain: "aws error", status: 500
      return
    end

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

  def sync_create(s3, params, project)
    unless params.has_key?(:file) then
      raise MyError, "file parameter is required for create method"
    end

    file = params[:file]

    File.open file.tempfile.path do |fp|
      s3.put_object({
        acl: "public-read",
        bucket: MyS3Client.bucketName,
        key: File.join(project.hashid.to_s, params[:destination]),
        body: fp
      })
    end
  end

  def sync_remove(s3, params, project)
    raise MyError, "not implemented"
  end

  def sync_move(s3, params, project)
    raise MyError, "not implemented"
  end

  def sync
    begin
      project = Project.find(params[:id])
    rescue ActiveRecord::RecordNotFound, Hashids::InputError
      render plain: "no such record", status: 404
      return
    end

    unless project.authenticate(params[:key])
      logger.info "unauth access to project-#{params[:id]} by #{request.remote_ip}"
      render plain: "no such record", status: 404
      return
    end

    if not params.has_key?(:destination)
      render plain: "destination param is required", status: 400
      return
    elsif params[:destination].include? ".." or
        (params.has_key?(:source) and params[:source].include? "..") then
      render plain: "malicious folder access", status: 403
      return
    end

    begin
      s3 = MyS3Client.get

      case params[:method]
        when "create"
          sync_create(s3, params, project)
        when "remove"
          sync_remove(s3, params, project)
        when "move"
          sync_move(s3, params, project)
        else
          render plain: "method parameter must be one of create, remove or move", status: 400
          return
      end
    rescue MyError => e
      render plain: e, status: 400
      return
    rescue Aws::Errors::ServiceError => e
      logger.error e
      render plain: "aws error", status: 500
      return
    end

    render plain: "ok"
  end
end
