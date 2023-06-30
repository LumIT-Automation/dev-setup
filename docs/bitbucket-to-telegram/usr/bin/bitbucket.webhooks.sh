#!/bin/bash

# Read POST data.
while read -t 0.5 line; do
    echo "$line" >> /tmp/bitbucket.post
done
request="$line" # only json payload.

echo "$request" >> /tmp/bitbucket.post.request

# Build message.
repository="$(echo "$request" | jq .repository.name | sed 's/\"//g')"
branch="$(echo "$request" | jq .changes[0].ref.displayId | sed 's/\"//g')"
author="$(echo "$request" | jq .commits[0].author.name | sed 's/\"//g')"
commit="$(echo "$request" | jq .commits[0].message | sed 's/\"//g')"

message="Push on ${repository} (${branch}) by ${author}
Message: ${commit}"

# Send message to Telegram A-Tram chat group.
echo "$message" > /tmp/telegram.message

botToken='...'
chatId='...' # see https://stackoverflow.com/questions/32423837/telegram-bot-how-to-get-a-group-chat-id

curl --location "https://api.telegram.org/bot${botToken}/sendMessage" \
--header 'Content-Type: application/json' \
--data "{
    \"chat_id\": \"$chatId\",
    \"text\": \"$message\"
}" >/dev/null 2>&1

# Response to client.
echo -e 'HTTP/1.0 200\r\nConnection:Close\r\nContent-Length: 0\r\n'