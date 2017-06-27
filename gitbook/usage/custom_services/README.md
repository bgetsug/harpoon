# Custom Services

You can also "plug in" your own custom service configurations and use
them with _Harpoon_. For example, let's create a custom service for
running MariaDB.

1. Create (or symlink) a directory named `custom` in your Harpoon
   `services` directory.
2. Create a directory named `mariadb` in `custom`.
3. In the `mariadb` directory:
   1. Create a file named `mariadb.yml`. The contents is just like any
      other `docker-compose.yml`, but with some _Harpoon_-driven
      environment variables:

      ```yaml
      version: '2'
        
      services:
        mariadb:
          container_name: harpoon_mariadb
          image: mariadb:${MARIADB_VERSION}
          environment:
            - MYSQL_ALLOW_EMPTY_PASSWORD=yes
            - MYSQL_DATABASE=${MARIADB_DATABASE}
          ports:
            - "${MARIADB_PORT}:3306"
          volumes:
            - mariadb:/var/lib/mysql
        
      networks:
        default:
          external:
            name: ${HARPOON_DOCKER_NETWORK}
        
      volumes:
        mariadb:
          external: true
      ```

   2. Create a file named `bootstrap.sh`. _Harpoon_ will use this to
      load any custom environment variables you'd like to set. You can
      also provide "hook" functions, which _Harpoon_ will call at
      various states of your service's lifecycle. (Examine
      [`services/services.sh`](../../../services/services.sh) for more
      details.)

      ```bash
      #!/usr/bin/env bash
        
      set -euo pipefail
        
      if [ ! ${MARIADB_VERSION:-} ]; then
          export MARIADB_VERSION="10.1"
      fi
        
      if [ ! ${MARIADB_DATABASE:-} ]; then
          export MARIADB_DATABASE="harpoon"
      fi
        
      if [ ! ${MARIADB_PORT:-} ]; then
          export MARIADB_PORT=3306
      fi
        
      export MARIADB_VOLUME_NAME=mariadb
        
      mariadb_pre_up() {
        VOLUME_CREATED=$(docker volume ls | grep ${MARIADB_VOLUME_NAME}) || true
        
        if [[ ! ${VOLUME_CREATED} ]]; then
            echo -e "${PURPLE}Creating docker volume named '${MARIADB_VOLUME_NAME}'...${NC}"
            docker volume create --name=${MARIADB_VOLUME_NAME}
        fi
      }
        
      mariadb_remove_volume() {
        VOLUME_CREATED=$(docker volume ls | grep ${MARIADB_VOLUME_NAME}) || true
        
        if [[ ${VOLUME_CREATED} ]]; then
            echo -e "${PURPLE}Removing docker volume named '${MARIADB_VOLUME_NAME}'...${NC}"
            docker volume rm ${MARIADB_VOLUME_NAME}
        fi
      }
        
      mariadb_post_destroy() {
          mariadb_remove_volume
      }
        
      mariadb_post_clean() {
          mariadb_remove_volume
      }
      ```

   3. Create a file named `handler.sh`. _Harpoon_ will use this to
      handle any custom commands for your service.

      ```bash
      #!/usr/bin/env bash
      
      set -euo pipefail
      
      case "${command:-}" in
          mariadb:client) ## [<arg>...] %% MySQL Client
              ${DOCKER_COMPOSE_CMD} ${DKR_COMPOSE_FILE} exec mariadb mysql -uroot "${args}" ;;
      
          mariadb:wait) ## %% Wait for MySQL to startup and finish initializing
              echo -e "Waiting for MySQL to start...\n"
      
              retries=30
              while [[ "$retries" > 0 ]]; do
                  ${DOCKER_COMPOSE_CMD} ${DKR_COMPOSE_FILE} exec mariadb mysql -uroot "-e SELECT 1" && break
                  let "retries=retries-1"
                  sleep 2
              done
              ;;
      
          mariadb:backup) ## %% Backup all databases in the mariadb container
              echo -e "Backing up all databases...\n"
              ${DOCKER_COMPOSE_CMD} ${DKR_COMPOSE_FILE} exec mariadb mysqldump -A --add-drop-database --add-drop-table -e -uroot > mariadb_backup.sql
              ;;
      
          mariadb:restore) ## %% Restore databases from mariadb_backup.sql in the current directory
              echo -e "Restoring from mariadb_backup.sql...\n"
              docker cp $PWD/mariadb_backup.sql harpoon_mariadb:/mariadb_backup.sql
              ${DOCKER_COMPOSE_CMD} ${DKR_COMPOSE_FILE} exec -T mariadb bash -c "mysql < /mariadb_backup.sql && rm -f /mariadb_backup.sql"
              ;;
      
          *)
              service_help mariadb ;;
      esac

      ```

      * Be sure to use the `${DOCKER_COMPOSE_CMD}` and
        `${DKR_COMPOSE_FILE}` variables for any calls you need to make
        to docker-compose with your configuration.
      * Also note the use of the `## [<arg>...] %% Your description`
        comment convention. _Harpoon_ will use this to automatically add
        your custom commands to the `help` output.

This service can now be managed with `harpoon mariadb:*`. Try `harpoon
mariadb:help` 😁
