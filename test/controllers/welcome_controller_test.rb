require 'test_helper'

class WelcomeControllerTest < ActionDispatch::IntegrationTest
  class WelcomeControllerIndexTest < ActionDispatch::IntegrationTest
    def setup
      get root_url
    end

    test "does not show navbar in root page" do
      assert_select "nav", false
    end

    test "has a link to project creation page" do
      assert_select "a[href=\"#{new_project_path}\"]", 1
    end

    test "has a link to about page" do
      assert_select "a[href=\"#{about_path}\"]", 1
    end
  end

  test "shows navbar in about page" do
    get about_url
    assert_select "nav", true
  end
end
