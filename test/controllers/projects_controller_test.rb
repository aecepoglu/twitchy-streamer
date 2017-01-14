require 'test_helper'
require 'minitest/mock'
require 'json'

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  def setup
    require "s3_client"

    ENV["AWS_REGION"] = "my-region"
    @s3 = MockedS3Client.new(Aws::S3::Client.new({stub_responses: true}))

    @projId = Project.find_by(:title => "two").hashid
  end

  def teardown
    ENV.delete("AWS_REGION")
    @s3._reset_calls!
  end

  test "dir should list files successfully" do
    @s3.stub_responses(:list_objects_v2, {
      contents: [
        {key: "my-proj-id/file1.js"},
        {key: "my-proj-id/file2"},
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
        {url: "#{urlPrefix}/folder1/file3.py", name: "file3.py", dir: "folder1", ext: "py", type: "application/x-python"}
      ].map(&sorter)), JSON.generate(JSON.parse(@response.body).map(&sorter))
    end
  end

  test "sync:should upload file to S3" do
    MyS3Client.stub :get, @s3 do
      @s3.stub_responses(:put_object, {
        etag: "some-etag-value"
      })

      post sync_project_path(id: @projId), params: {
        method: "created",
        key: "password-two",
        destination: "sample.js",
        file: fixture_file_upload("test/fixtures/files/sample.js", "application/javascript"),
      }
    end

    assert_equal "ok", @response.body
    assert_response :success
  end

  test "sync:should 400 if method is not given" do
    post sync_project_path(id: @projId), params: {
      key: "password-two",
      destination: "sample.js",
      file: fixture_file_upload("test/fixtures/files/sample.js", "application/javascript"),
    }

    assert_response 400
  end

  ["created", "deleted", "moved", "modified"].each do |method|
    test "sync:#{method} should 404 if project can't be found" do
      post sync_project_path(id: "nonexistent-id"), params: {
        method: method,
        key: "password-two",
        destination: "sample.js",
        file: fixture_file_upload("test/fixtures/files/sample.js", "application/javascript"),
      }

      assert_response :missing
    end

    test "sync:#{method} should 404 if key is wrong" do
      post sync_project_path(id: @projId), params: {
        method: method,
        key: "wrong password",
        destination: "sample.js",
        file: fixture_file_upload("test/fixtures/files/sample.js", "application/javascript"),
      }

      assert_response :missing
    end

    test "sync:#{method} should 403 if destination contains '..'" do
      post sync_project_path(id: @projId), params: {
        method: method,
        key: "password-two",
        destination: "../malicious-path/sample.js",
        file: fixture_file_upload("test/fixtures/files/sample.js", "application/javascript"),
      }

      #TODO and also test that a strike has been put on the project. 2 strikes and project is banned

      assert_response 403
    end

    test "sync:#{method} should 400 if destination parameter is not given" do
      post sync_project_path(id: @projId), params: {
        method: "created",
        key: "password-two",
        file: fixture_file_upload("test/fixtures/files/sample.js", "application/javascript"),
      }

      assert_response 400
    end
  end

  test "sync:create should 400 if file parameter is not given" do
      post sync_project_path(id: @projId), params: {
        method: "created",
        key: "password-two",
        destination: "sample.js"
      }

      assert_response 400
  end

  test "sync:create should 500 if s3 upload failed" do
    MyS3Client.stub :get, @s3 do
      @s3.stub_responses(:put_object, "an error")

      post sync_project_path(id: @projId), params: {
        method: "created",
        key: "password-two",
        destination: "sample.js",
        file: fixture_file_upload("test/fixtures/files/sample.js", "application/javascript"),
      }
    end

    assert_response :error
    assert_equal "aws error", @response.body
  end

  test "sync:move should 400 if source parameter is not given" do
    post sync_project_path(id: @projId), params: {
      method: "moved",
      key: "password-two",
      destination: "path/to/new-sample.js",
    }

    assert_response 400
  end

  test "sync:move should 403 if source parameter contains .." do
    post sync_project_path(id: @projId), params: {
      method: "moved",
      key: "password-two",
      source: "../another-project/file.js",
      destination: "file.js"
    }

    assert_response 403
  end

  test "sync:move should copy item to new location and remove the old one" do
    MyS3Client.stub :get, @s3 do
      post sync_project_path(id: @projId), params: {
        method: "moved",
        key: "password-two",
        source: "old-sample.js",
        destination: "path/to/new-sample.js"
      }
    end

    assert_response :success

    assert_equal({
      acl: "public-read",
      bucket: "twitchy-streamer",
      key: @projId.to_s + "/path/to/new-sample.js",
      copy_source: "twitchy-streamer/#{@projId.to_s}/old-sample.js"
    }, @s3._args_for(:copy_object)[0][0])

    assert_equal({
      bucket: "twitchy-streamer",
      key: @projId.to_s + "/old-sample.js",
    }, @s3._args_for(:delete_object)[0][0])
  end

  test "sync:move should 404 if source doesn't exist" do
    MyS3Client.stub :get, @s3 do
      @s3.stub_responses(:copy_object, "NoSuchKey")

      post sync_project_path(id: @projId), params: {
        method: "moved",
        key: "password-two",
        source: "source.txt",
        destination: "destination.txt"
      }

      assert_response 404
    end
  end

  test "sync:delete should delete the given item" do
    MyS3Client.stub :get, @s3 do
      post sync_project_path(id: @projId), params: {
        method: "deleted",
        key: "password-two",
        destination: "file.txt"
      }
    end

    assert_response :success

    assert_equal({
      bucket: "twitchy-streamer",
      key: @projId.to_s + "/file.txt",
    }, @s3._args_for(:delete_object)[0][0])
  end

  test "sync:delete should 404 if given item doesn't exist" do
    MyS3Client.stub :get, @s3 do
      @s3.stub_responses(:delete_object, "NoSuchKey")

      post sync_project_path(id: @projId), params: {
        method: "deleted",
        destinatio: "file.txt"
      }

      assert_response 404
    end
  end
end
