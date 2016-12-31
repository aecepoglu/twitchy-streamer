require 'test_helper'
require 'minitest/mock'
require 'json'
require 'aws-sdk'
require 'delegate'

class MockedS3Client < DelegateClass(Aws::S3::Client)
  def initialize(x)
    super(x)
  end

  def list_objects_v2(props)
    throw "this is another error" if props[:prefix] != "my-proj-id"

    super props
  end
end

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  def setup
    require "s3_client"

    ENV["AWS_REGION"] = "my-region"
    @s3 = MockedS3Client.new(Aws::S3::Client.new({stub_responses: true}))
  end

  def teardown
    ENV["AWS_REGION"] = nil
  end

  test "dir should list files successfully" do
    @s3.stub_responses(:list_objects_v2, {
      contents: [
        {key: "my-proj-id/"},
        {key: "my-proj-id/file1.js"},
        {key: "my-proj-id/file2"},
        {key: "my-proj-id/folder1/"},
        {key: "my-proj-id/folder1/file3.py"}
      ]
    })

    MyS3Client.stub :get, @s3 do
      urlPrefix = MyS3Client.bucketUrl + "/" + "my-proj-id"

      sorter = lambda { |x|
        x.sort_by { |key, val| key }
      }

      get dir_project_path id: "my-proj-id"
      
      assert_equal JSON.generate([
        {url: "#{urlPrefix}/file1.js", name: "file1.js", dir: nil, ext: "js", type: "application/javascript"},
        {url: "#{urlPrefix}/file2", name: "file2", dir: nil, ext: "", type: "text/plain"},
        {name: "folder1", dir: nil},
        {url: "#{urlPrefix}/folder1/file3.py", name: "file3.py", dir: "folder1", ext: "py", type: "application/x-python"}
      ].map(&sorter)), JSON.generate(JSON.parse(@response.body).map(&sorter))
    end
  end
end
