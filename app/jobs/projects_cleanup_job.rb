require 's3_client'

class ProjectsCleanupJob < ApplicationJob
  queue_as :default

  def perform()
    puts "cleanup ran at #{Time.now}"

    Project.where("updated_at < :date", {date: Time.now - 48*3600}).find_each do |project|
      hashid = project.hashid

      puts "cleanup PURGE id=#{hashid}"

      project.destroy

      s3 = MyS3Client.get

      resp = s3.list_objects_v2({
        bucket: MyS3Client.bucketName,
        prefix: hashid
      })

      s3.delete_objects({
        bucket: MyS3Client.bucketName,
        delete: {
          objects: resp.contents.map { |it| { key: it.key } }
        }
      })
    end
  end
end
