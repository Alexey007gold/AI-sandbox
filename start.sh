docker run -it \
  -v $(pwd):$(pwd) \
  -v /Users/oleksii/.claude:/home/ubuntu/.claude \
  -v /Users/oleksii/.claude-mem:/home/ubuntu/.claude-mem \
  -v /Users/oleksii/.claude.json:/home/ubuntu/.claude.json \
   sbx \
   bash