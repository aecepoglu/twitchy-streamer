class WelcomeController < ApplicationController
  def index
  end

  def about
    @buildInfo = Rails.configuration.build_info
  end
end
