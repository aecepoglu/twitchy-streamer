class VersionController < ApplicationController
  def list
    render plain: "#{Rails.configuration.build_info[:version]}"
  end
end
