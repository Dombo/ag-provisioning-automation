#! /bin/bash

ansible_directory=$1
shift

cat <<-EOF
#! /bin/bash

set -o errexit

apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install ansible --no-install-recommends -y

mkdir -p /tmp/ansible
echo '$(tar c -C "$ansible_directory" . | gzip -n | base64 | tr -d \\n)' | base64 -d | tar xz -C /tmp/ansible
cd /tmp/ansible
EOF

echo -n '/usr/bin/ansible-playbook playbook.yml --connection=local -i localhost, -e target=localhost'