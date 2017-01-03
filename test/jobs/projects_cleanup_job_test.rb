require 'test_helper'
require 'minitest/mock'
require 's3_client'

class ProjectsCleanupJobTest < ActiveJob::TestCase
  def setup
    @projects = (0..10).map do |numDays|
      Project.create(title: "#{numDays}-ago", password: "pass", updated_at: Time.now - numDays*24*3600 - 100)
    end

    ENV["AWS_REGION"] = "test-region"
    @s3 = MockedS3Client.new(Aws::S3::Client.new({stub_responses: true}))
  end

  def teardown
    ENV.delete "AWS_REGION"
    @s3._reset_calls!
    @projects.each { |it|
      if Project.exists?(it.id)
        it.destroy
      end
    }
  end

  test "test data exists" do
    @projects.each { |it|
      assert it.valid?
    }

    assert_equal 11, @projects.length
    assert Project.count >= 11
  end

  test "deletes records untouched more than 5 days" do
    lengthBefore = Project.count
    DELETE_DAYS = 2

    @s3.stub_responses(:list_objects_v2, {
      contents: [
        {key: "key-1", etag: "etag-1"},
        {key: "key-2", etag: "etag-2"},
      ]
    })

    MyS3Client.stub :get, @s3 do
      ProjectsCleanupJob.perform_now
    end

    listCalls = @s3._args_for :list_objects_v2
    deleteCalls = @s3._args_for :delete_objects

    assert_equal (lengthBefore - (11 - DELETE_DAYS)), Project.count
    assert_equal (11 - DELETE_DAYS), listCalls.length
    assert_equal (11 - DELETE_DAYS), deleteCalls.length

    (DELETE_DAYS..10).each do |num|
      assert_equal({
        bucket: MyS3Client.bucketName,
        prefix: @projects[num].hashid
      }, listCalls[num - DELETE_DAYS][0])

      assert_equal({
        bucket: MyS3Client.bucketName,
        delete: {
          objects: [
            {key: "key-1"},
            {key: "key-2"}
          ]
        }
      }, deleteCalls[num - DELETE_DAYS][0])
    end
  end
end
