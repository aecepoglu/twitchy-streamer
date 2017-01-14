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

    if @proj.save()
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

  def get_file_info(key, prefix, bucketUrl)
    path = key[(prefix.length + 1)..-1]

    dir = File.dirname(path)
    ext = File.extname(path)[1..-1] || ""
    types = MIME::Types.type_for(ext)

    file = {
      name: File.basename(path),
      dir: dir == "." ? nil : dir,
      url: File.join(bucketUrl, key),
      ext: ext,
      type: types.length >= 1 ? types[0].to_s : "text/plain"
    }

    return file
  end
  

  def dir
    resp = nil

    begin
      s3 = MyS3Client.get

      prefix = params[:id].to_s
      resp = s3.list_objects_v2({
        bucket: MyS3Client.bucketName,
        prefix: prefix + "/"
      })
    rescue Aws::Errors::MissingRegionError,
        Aws::Errors::MissingCredentialsError,
        Aws::Errors::ServiceError => e
      logger.tagged("aws") { logger.error e }
      render plain: "aws error", status: 500
      return
    end

    files = []
    bucketUrl = MyS3Client.bucketUrl

    files = resp.contents.map { |x|
      get_file_info(x.key, prefix, bucketUrl)
    }

    render json: files
  end

  def sync_create(s3, params, project)
    unless params.has_key?(:file)
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

  def sync_delete(s3, params, project)
    s3.delete_object({
      bucket: MyS3Client.bucketName,
      key: File.join(project.hashid.to_s, params[:destination])
    })
  end

  def sync_move(s3, params, project)
    unless params.has_key?(:source)
      raise MyError, "'source' parameter is required for 'move' method"
    end

    s3.copy_object({
      acl: "public-read",
      bucket: MyS3Client.bucketName,
      copy_source: File.join(MyS3Client.bucketName, project.hashid.to_s, params[:source]),
      key: File.join(project.hashid.to_s, params[:destination])
    })

    s3.delete_object({
      bucket: MyS3Client.bucketName,
      key: File.join(project.hashid.to_s, params[:source])
    })
  end

  def sync
    logger.tagged("sync") {
      logger.info params.permit(:id, :method, :source, :destination).inspect
    }

    begin
      project = Project.find(params[:id])
    rescue ActiveRecord::RecordNotFound, Hashids::InputError
      render plain: "no such record", status: 404
      return
    end

    unless project.authenticate(params[:key])
      logger.warn "unauth-access project=#{params[:id]} ip=#{request.remote_ip}"
      render plain: "no such record", status: 404
      return
    end

    if not params.has_key?(:destination)
      render plain: "destination param is required", status: 400
      return
    elsif params[:destination].include? ".." or
        (params.has_key?(:source) and params[:source].include? "..")
      logger.warn "malicious-access project=#{request.remote_ip}"
      render plain: "malicious folder access", status: 403
      return
    end

    begin
      s3 = MyS3Client.get

      case params[:method]
        when "created"
          sync_create(s3, params, project)
        when "modified"
          sync_create(s3, params, project)
        when "deleted"
          sync_delete(s3, params, project)
        when "moved"
          sync_move(s3, params, project)
        else
          render plain: "method parameter must be either 'created', 'delete' or 'move', 'modified'", status: 400
          return
      end
    rescue MyError => e
      render plain: e, status: 400
      return
    rescue Aws::S3::Errors::NoSuchKey => e
      logger.tagged("aws") { logger.error e }
      render plain: "sync error with aws", status: 404
      return
    rescue Aws::Errors::ServiceError => e
      logger.tagged("aws") { logger.error e }
      render plain: "aws error", status: 500
      return
    end

    ActionCable.server.broadcast("project-#{project.hashid}", 
      {method: params[:method]}.merge(get_file_info(
        File.join(project.hashid, params[:destination]),
        project.hashid.to_s,
        MyS3Client.bucketUrl
      ))
    )
    project.touch

    render plain: "ok"
  end
end
