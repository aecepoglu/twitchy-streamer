require 'test_helper'

class ProjectTest < ActiveSupport::TestCase
  def setup
    @validParams = {:title => "my title", :password => "my password"}
    @validProj = Project.new(@validParams)
  end

  test "valid project" do
    assert @validProj.valid?
  end

  test "invalid without 'title'" do
    @validProj.title = nil

    assert_not @validProj.valid?
    assert_not_nil @validProj.errors[:title]
  end

  test "invalid without 'password'" do
    @validParams[:password] = nil

    proj = Project.new(@validParams)

    assert_not proj.valid?
    assert_not_nil proj.errors[:password]
  end

  test "authentication" do
    assert @validProj.authenticate("my password")
  end
end
