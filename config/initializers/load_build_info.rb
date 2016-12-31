info = YAML.load_file(Rails.root.join("config/build_info.yml"))

Rails.configuration.build_info = {
  date: info["date"],
  version: info["version"]
}
