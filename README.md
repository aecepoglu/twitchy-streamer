[![Codeship Status for aecepoglu/twitchy-streamer](https://app.codeship.com/projects/1002c4b0-aded-0134-02cb-42bf2211c7d1/status?branch=master)](https://app.codeship.com/projects/192582)
[![codecov](https://codecov.io/gh/aecepoglu/twitchy-streamer/branch/master/graph/badge.svg)](https://codecov.io/gh/aecepoglu/twitchy-streamer)

# README


### Configuration

* `AWS_REGION` - required
* `AWS_ACCESS_KEY_ID` - required
* `AWS_SECRET_ACCESS_KEY` - required
* `CODECOV_TOKEN` - optional. If exists pushes to codecov

Rails v5.0

### To Start

    rails server

### To Test

    rails test

### Development

Change your .git/hooks/pre-commit to this

    exec hooks/pre-commit.sh

And commit like this to update build info (`build_info.yml`)

    BUILDINFO=yes git commit ...

#TODO

* System dependencies
* Ruby

* Database creation
* Database initialization

* Deployment instructions
