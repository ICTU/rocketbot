#! /bin/sh
su -c "echo n | yo hubot --owner='$BOT_OWNER' --name='$BOT_NAME' --description='$BOT_DESC' --defaults && \
       sed -i /heroku/d ./external-scripts.json && \
       sed -i /redis-brain/d ./external-scripts.json && \
       npm install hubot-scripts" - hubot

cp -r /src /home/hubot/node_modules/hubot-rocketchat
chown hubot:hubot -R /home/hubot/node_modules/hubot-rocketchat

su -c 'rm -rf /home/hubot/node_modules/hubot-rocketchat/.git && \
       cd /home/hubot/node_modules/hubot-rocketchat && \
       npm install && \
       coffee -c /home/hubot/node_modules/hubot-rocketchat/src/*.coffee && \
       cp -a scripts/. /home/hubot/scripts/ && \
       cd /home/hubot/scripts && \
       npm install && \
       rm /home/hubot/hubot-scripts.json && \
       rm /home/hubot/external-scripts.json && \
       rm /home/hubot/scripts/example.coffee' - hubot

cp -a /home/hubot/. /dist/
