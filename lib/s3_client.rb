require 'aws-sdk'

module MyS3Client
  @@client = nil

  def self.get(alwaysCreateNew = false)
    if not @@client or alwaysCreateNew
      @@client = Aws::S3::Client.new()
    end
    
    return @@client
  end

  def self.bucketName
    return ENV["AWS_BUCKET"] || "twitchy-streamer"
  end

  def self.bucketUrl
    Aws::S3::Bucket.new(self.bucketName).url
  end
end
