require 's3_client'

class ProjectsCleanupJob < ApplicationJob
  queue_as :default

  def perform()
    puts "cleanup ran at #{Time.now}"

    Project.where("updated_at < :date", {date: Time.now - 168*3600}).find_each do |project|
      hashid = project.hashid

      puts "cleanup PURGE id=#{hashid}"

      s3 = MyS3Client.get

      resp = s3.list_objects_v2({
        bucket: MyS3Client.bucketName,
        prefix: hashid
      })

      if resp.contents.length == 0
        next
      end

      s3.delete_objects({
        bucket: MyS3Client.bucketName,
        delete: {
          objects: resp.contents.map { |it| { key: it.key } }
        }
      })

      project.destroy
    end
  end
end
