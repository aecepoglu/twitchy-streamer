ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'aws-sdk'
require 'delegate'

class MockedS3Client < DelegateClass(Aws::S3::Client)
  @@call_args = []

  def initialize(x)
    super(x)
  end

  def list_objects_v2(props)
    @@call_args.push [:list_objects_v2, [props]]
    super props
  end

  def put_object(props)
    @@call_args.push [:put_object, [props]]
    super props
  end

  def copy_object(props)
    @@call_args.push [:copy_object, [props]]
    super props
  end

  def delete_object(props)
    @@call_args.push [:delete_object, [props]]
    super props
  end

  def delete_objects(props)
    @@call_args.push [:delete_objects, [props]]
    super props
  end

  def _args_for(methodName)
    return @@call_args.select { |x|
      x[0] == methodName
    }.collect { |x|
      x[1]
    }
  end

  def _reset_calls!
    @@call_args.clear
  end
end


class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end
