puts "reading projects_channel file"

class ProjectsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "project-#{params[:id]}"
  end
end
