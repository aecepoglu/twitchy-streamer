info = YAML.load_file(Rails.root.join("config/build_info.yml"))

version = info["version"]
index = version.index('-') || version.length

Rails.configuration.build_info = {
  date: info["date"],
  version: version[0..(index -1)],
  version_extra: version[index..-1]
}
