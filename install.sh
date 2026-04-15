sudo ln -sf '$pwd/list.sh' /usr/local/bin/csbx-ps
sudo chmod +x '$pwd/list.sh'

sudo ln -sf '$pwd/start.sh' /usr/local/bin/csbx
sudo chmod +x '$pwd/start.sh'

mv $HOME/.claude.json $HOME/.claude/claude_.json
ln -sfn $HOME/.claude/claude_.json $HOME/.claude.json