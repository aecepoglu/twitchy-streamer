class HealthCheckController < ApplicationController
  def show
    render json: "OK"
  end
end
