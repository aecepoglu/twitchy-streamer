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

    @projId = Project.find_by(:title => "two").id
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

      get dir_project_path id: "my-proj-id", xhr: true
      
      assert_equal JSON.generate([
        {url: "#{urlPrefix}/file1.js", name: "file1.js", dir: nil, ext: "js", type: "application/javascript"},
        {url: "#{urlPrefix}/file2", name: "file2", dir: nil, ext: "", type: "text/plain"},
        {name: "folder1", dir: nil},
        {url: "#{urlPrefix}/folder1/file3.py", name: "file3.py", dir: "folder1", ext: "py", type: "application/x-python"}
      ].map(&sorter)), JSON.generate(JSON.parse(@response.body).map(&sorter))
    end
  end

  test "sync should upload file to S3" do
    MyS3Client.stub :get, @s3 do
      @s3.stub_responses(:put_object, {
        etag: "some-etag-value"
      })

      post sync_project_path(id: @projId), params: {
        key: "password-two",
        dir: "",
        file: fixture_file_upload("test/fixtures/files/sample.js", "application/javascript"),
      }
    end

    assert_response :success
  end

  test "sync should 404 if project can't be found" do
    post sync_project_path(id: "nonexistent-id"), params: {
      key: "password-two",
      dir: "",
      file: fixture_file_upload("test/fixtures/files/sample.js", "application/javascript"),
    }

    assert_response :missing
  end

  test "sync should 404 if key is wrong" do
    post sync_project_path(id: @projId), params: {
      key: "wrong password",
      dir: "",
      file: fixture_file_upload("test/fixtures/files/sample.js", "application/javascript"),
    }

    assert_response :missing
  end

  test "sync should 403 if dir contains '..'" do
    post sync_project_path(id: @projId), params: {
      key: "password-two",
      dir: "../malicious-path",
      file: fixture_file_upload("test/fixtures/files/sample.js", "application/javascript"),
    }

    #TODO and also test that a strike has been put on the project. 2 strikes and project is banned

    assert_response 403
  end

  ["dir", "file"].each do |param|
    test "sync should 400 if #{param} parameter is not given" do

      post sync_project_path(id: @projId), params: {
        key: "password-two",
        dir: "",
        file: fixture_file_upload("test/fixtures/files/sample.js", "application/javascript"),
      }.stringify_keys.except(param)

      #assert_response(400)
    end
  end

  test "sync should 500 if s3 upload failed" do
    MyS3Client.stub :get, @s3 do
      @s3.stub_responses(:put_object, "an error")

      post sync_project_path(id: @projId), params: {
        key: "password-two",
        dir: "",
        file: fixture_file_upload("test/fixtures/files/sample.js", "application/javascript"),
      }
    end

    assert_response :error
    assert_equal "aws upload error", @response.body
  end
end
