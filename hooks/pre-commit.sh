#!/bin/sh

echo "date: $(git log -1 --pretty="%ad" --date=short)
version: $(git tag)" > config/build_info.yml

git update-index --add config/build_info.yml
