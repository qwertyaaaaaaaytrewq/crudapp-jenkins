pipeline {
    agent { label 'docker-agent' }

    environment {
        APP_NAME = 'app'
        CANARY_APP_NAME = 'app-canary'

        DOCKER_HUB_USER = 'qwertyaaaaaaaytrewq'
        GIT_REPO = 'https://github.com/qwertyaaaaaaaytrewq/crudapp-jenkins.git'

        BACKEND_IMAGE_NAME = 'front'
        DATABASE_IMAGE_NAME = 'mysql'

        MANAGER_IP = '192.168.0.1'

        MYSQL_ROOT_PASSWORD = '1'
        MYSQL_DATABASE = 'db'

        DOCKER_HOST = 'tcp://192.168.0.1:2376'
        DOCKER_BUILDKIT = '1'
    }

    stages {

        stage('Checkout') {
            steps {
                deleteDir()

                retry(3) {
                    git branch: 'main',
                        url: "${GIT_REPO}"
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                retry(3) {
                    sh '''
                        docker build --network=host \
                            -f node.Dockerfile \
                            -t ${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER} .

                        docker build --network=host \
                            -f mysql.Dockerfile \
                            -t ${DOCKER_HUB_USER}/${DATABASE_IMAGE_NAME}:${BUILD_NUMBER} .
                    '''
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'docker-hub-credentials',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login \
                            -u "$DOCKER_USER" \
                            --password-stdin

                        docker push \
                            ${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER}

                        docker push \
                            ${DOCKER_HUB_USER}/${DATABASE_IMAGE_NAME}:${BUILD_NUMBER}
                    '''
                }
            }
        }

        stage('Deploy Canary') {
            steps {
                sh '''
                    echo "=== Развёртывание Canary ==="

                    docker stack deploy \
                        -c docker-compose_canary.yaml \
                        ${CANARY_APP_NAME} \
                        --with-registry-auth

                    sleep 40

                    docker service ls \
                        --filter name=${CANARY_APP_NAME}
                '''
            }
        }

        stage('Canary Testing') {
            steps {
                sh '''
                    echo "=== Проверка Canary-приложения ==="

                    SUCCESS=0

                    for i in $(seq 1 10)
                    do
                        if curl -fsS --max-time 15 \
                            http://${MANAGER_IP}:8081/api/test
                        then
                            echo "Test $i: SUCCESS"
                            SUCCESS=$((SUCCESS + 1))
                        else
                            echo "Test $i: FAILED"
                        fi

                        sleep 4
                    done

                    echo "Successful tests: $SUCCESS/10"

                    [ "$SUCCESS" -ge 8 ]
                '''
            }
        }

        stage('Database Validation') {
            steps {
                sh '''
                    echo "======================================"
                    echo "Проверка структуры базы данных"
                    echo "Таблица: profiles"
                    echo "Поле: allergies"
                    echo "Ожидаемый тип: TEXT"
                    echo "======================================"

                    DB_SERVICE="${CANARY_APP_NAME}_db"

                    echo "Определяем ноду, на которой запущена Canary-БД..."

                    DB_NODE=$(docker service ps \
                        --filter desired-state=running \
                        --format '{{.Node}}' \
                        "$DB_SERVICE" | head -1)

                    if [ -z "$DB_NODE" ]; then
                        echo "ERROR: не найдена нода с Canary-БД"
                        exit 1
                    fi

                    echo "База запущена на ноде: $DB_NODE"

                    DB_NODE_IP=$(docker node inspect \
                        "$DB_NODE" \
                        --format '{{.Status.Addr}}')

                    if [ -z "$DB_NODE_IP" ]; then
                        echo "ERROR: не удалось определить IP ноды"
                        exit 1
                    fi

                    echo "IP ноды: $DB_NODE_IP"

                    echo "Ожидание готовности контейнера MySQL..."

                    READY=0
                    DB_CONTAINER=""

                    for i in $(seq 1 30)
                    do
                        DB_CONTAINER=$(docker \
                            -H tcp://${DB_NODE_IP}:2376 \
                            ps \
                            --filter "name=${CANARY_APP_NAME}_db" \
                            --format '{{.ID}}' | head -1)

                        if [ -n "$DB_CONTAINER" ]; then

                            if docker \
                                -H tcp://${DB_NODE_IP}:2376 \
                                exec "$DB_CONTAINER" \
                                mysqladmin ping \
                                -uroot \
                                -p"${MYSQL_ROOT_PASSWORD}" \
                                --silent
                            then
                                READY=1
                                echo "MySQL готов"
                                break
                            fi
                        fi

                        echo "Попытка $i/30..."
                        sleep 3
                    done

                    if [ "$READY" -ne 1 ]; then
                        echo "ERROR: MySQL не запустился"
                        exit 1
                    fi

                    echo "Проверяем тип profiles.allergies..."

                    FIELD_TYPE=$(docker \
                        -H tcp://${DB_NODE_IP}:2376 \
                        exec "$DB_CONTAINER" \
                        mysql \
                        -uroot \
                        -p"${MYSQL_ROOT_PASSWORD}" \
                        -D "${MYSQL_DATABASE}" \
                        -Nse "
                            SELECT LOWER(DATA_TYPE)
                            FROM INFORMATION_SCHEMA.COLUMNS
                            WHERE TABLE_SCHEMA='${MYSQL_DATABASE}'
                              AND TABLE_NAME='profiles'
                              AND COLUMN_NAME='allergies';
                        " 2>/dev/null | tr -d '\\r\\n ')

                    echo "Найден тип поля allergies: [$FIELD_TYPE]"

                    if [ "$FIELD_TYPE" = "text" ]; then
                        echo "======================================"
                        echo "DATABASE VALIDATION: SUCCESS"
                        echo "profiles.allergies имеет тип TEXT"
                        echo "======================================"
                    else
                        echo "======================================"
                        echo "DATABASE VALIDATION: FAILED"
                        echo "Ожидался тип TEXT"
                        echo "Получен тип: $FIELD_TYPE"
                        echo "======================================"
                        exit 1
                    fi
                '''
            }
        }

        stage('Deploy Production') {
            steps {
                sh '''
                    echo "=== Развёртывание Production ==="

                    docker stack deploy \
                        -c docker-compose.yaml \
                        ${APP_NAME} \
                        --with-registry-auth

                    sleep 60

                    docker service ls
                '''
            }
        }

        stage('Final Verification') {
            steps {
                sh '''
                    echo "=== Финальная проверка ==="

                    SUCCESS=0

                    for i in $(seq 1 5)
                    do
                        if curl -fsS --max-time 15 \
                            http://${MANAGER_IP}:8080/api/test
                        then
                            echo "Final test $i: SUCCESS"
                            SUCCESS=$((SUCCESS + 1))
                        else
                            echo "Final test $i: FAILED"
                        fi

                        sleep 3
                    done

                    echo "Successful final tests: $SUCCESS/5"

                    [ "$SUCCESS" -ge 4 ]
                '''
            }
        }

        stage('Remove Canary') {
            steps {
                sh '''
                    docker stack rm ${CANARY_APP_NAME}
                '''
            }
        }
    }

    post {

        success {
            echo 'SUCCESS: Pipeline completed.'

            sh '''
                docker logout || true
            '''
        }

        failure {
            echo 'FAILURE: Pipeline stopped.'

            sh '''
                echo "Удаляем тестовую Canary-версию..."
                docker stack rm ${CANARY_APP_NAME} || true
                docker logout || true
            '''
        }

        always {
            echo 'Pipeline finished.'
        }
    }
}