docker run -it \
  -v $(pwd):$(pwd) \
  -v /Users/oleksii/.claude:/root/.claude \
  -v /Users/oleksii/.claude-mem:/root/.claude-mem \
  -v /Users/oleksii/.claude.json:/root/.claude.json \
  -e ELASTIC_API_KEY \
  -e KIBANA_URL \
  -e KIBANA_QA_API_KEY \
  -e KIBANA_QA_URL \
  -e KIBANA_PROD_API_KEY \
  -e KIBANA_PROD_URL \
  -w $(pwd) \
   sbx \
   bash -c "claude --dangerously-skip-permissions"