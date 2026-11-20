#!/bin/sh
mkdir -p -m 700 "$HOME/.1password"
conf=/etc/ssh/sshd_config.d/100-vm-ssh-agent.conf
[ -f "$conf" ] || echo 'StreamLocalBindUnlink yes' | sudo tee "$conf" >/dev/null
