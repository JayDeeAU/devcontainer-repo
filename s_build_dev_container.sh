#!/bin/bash
#!/bin/bash
#SSH_HOST=172.29.208.1
SSH_HOST=$DOCKER_HOST
WORKSPACE=/share/DevelopmentProjects/MagmaBI-Full

EXEC_CMD_BUILD="cd $WORKSPACE/.devcontainer &&  docker build --pull --rm -f 'Dockerfile' -t codedev:latest '.'"

# Execute commands on the remote server using ssh
echo "Running command on $SSH_HOST: $EXEC_CMD_BUILD"
ssh $SSH_HOST -t "/bin/bash -c '$EXEC_CMD_BUILD'"

# ssh $SSH_HOST "/bin/bash -c 'cd /share/DevelopmentProjects/MagmaBI-Full &&  docker build --pull --rm -f "backend/Dockerfile" -t magmabi-full_frontend:latest "backend"'"
