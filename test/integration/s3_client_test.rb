require 'test_helper'

class S3ClientTest < ActiveSupport::TestCase
  def setup
    ENV["AWS_REGION"] = "my-aws-region"
    ENV["AWS_ACCESS_KEY_ID"] = "my-aws-key"
    ENV["AWS_SECRET_ACCESS_KEY"] = "my-aws-secret"
    ENV["AWS_BUCKET"] = "my-bucket"

    require "s3_client"
  end

  def teardown
    [
      "AWS_REGION",
      "AWS_ACCESS_KEY_ID",
      "AWS_SECRET_ACCESS_KEY",
      "AWS_BUCKET"
    ].each { |x| ENV[x] = nil }
  end

  test ".get returns new s3 client" do
    s3 = MyS3Client.get

    assert s3.is_a? Aws::S3::Client

    assert_equal s3.config.region, "my-aws-region"
    assert_equal s3.config.credentials.access_key_id, "my-aws-key"
    assert_equal s3.config.credentials.secret_access_key, "my-aws-secret"
  end

  test ".bucketUrl" do
    assert_equal MyS3Client.bucketUrl, Aws::S3::Bucket.new("my-bucket").url
  end

  test "exposes S3_BUCKET" do
    assert_equal MyS3Client.bucketName, "my-bucket"
  end
end
