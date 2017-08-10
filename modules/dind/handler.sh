#!/usr/bin/env bash

if [ ! -v DIND_IMAGE ]; then
	export DIND_IMAGE=wheniwork/harpoon
fi

if [ ! -v DIND_STORAGE_DRIVER ]; then
	export DIND_STORAGE_DRIVER=aufs
fi

if [ ! -v DIND_HOME ]; then
	export DIND_HOME=$HOME
fi

case "${command:-}" in
	dind:start) ## %% 🐳  Start the docker-in-docker container
		docker pull ${DIND_IMAGE}

		CI_ARGS=""

		for c in $(env | grep CI); do
			CI_ARGS+=" -e $c"
		done

		docker run --rm -e APP_IMAGE -e USER_UID -e USER_GID ${CI_ARGS} \
		-v $PWD:$PWD -v ${DIND_HOME}/.docker:/root/.docker -v ${DIND_HOME}/.ssh:/root/.ssh \
		--workdir $PWD --privileged --name ${COMPOSE_PROJECT_NAME}_dind -d ${DIND_IMAGE} --storage-driver=${DIND_STORAGE_DRIVER}
		;;

	dind:stop) ## %% 🐳  Stop the docker-in-docker container
		docker stop ${COMPOSE_PROJECT_NAME}_dind ;;

	dind:exec) ## %% 🐳  Run a command inside the docker-in-docker container
		${DIND_EXEC} ${args} ;;

	dind:exec:it) ## %% 🐳  Run an interactive command inside the docker-in-docker container
		${DIND_EXEC_IT} ${args} ;;

	*)
		module_help
esac