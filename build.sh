#! /bin/sh
docker build -f Dockerfile.build.base -t ictu/rocketbot-build-base .
docker run -it --rm \
  -v $PWD/dist:/dist \
  -v $PWD/build-hubot.sh:/build-hubot.sh \
  -v $PWD:/src \
  -e BOT_NAME="ictubot" \
  -e BOT_OWNER="ICTU ISD" \
  -e BOT_DESC="ICTU ISD automation bot" \
  ictu/rocketbot-build-base sh /build-hubot.sh
docker build -f Dockerfile.prod -t ictu/rocketbot .
