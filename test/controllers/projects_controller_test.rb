require 'test_helper'

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  def setup
    get new_project_path
  end

  test "the truth" do
    assert true
  end
end
