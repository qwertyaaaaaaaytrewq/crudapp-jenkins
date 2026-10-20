pipeline {
    agent {
        label 'docker-agent'
    }

    options {
        skipDefaultCheckout(true)
    }

    environment {
        APP_NAME = 'app'
        CANARY_APP_NAME = 'app-canary'

        DOCKER_HUB_USER = 'qwertyaaaaaaaytrewq'

        GIT_REPO = 'https://github.com/qwertyaaaaaaaytrewq/crudapp-jenkins.git'

        BACKEND_IMAGE_NAME = 'front'
        DATABASE_IMAGE_NAME = 'mysql'

        MANAGER_IP = '192.168.0.1'
    }

    stages {

        stage('Checkout') {
            steps {
                deleteDir()

                retry(3) {
                    checkout([
                        $class: 'GitSCM',

                        branches: [[
                            name: '*/main'
                        ]],

                        userRemoteConfigs: [[
                            url: "${GIT_REPO}"
                        ]],

                        extensions: [[
                            $class: 'CloneOption',
                            shallow: true,
                            depth: 1,
                            noTags: true,
                            timeout: 20
                        ]]
                    ])
                }
            }
        }

        stage('Build Docker Images') {
            steps {

                retry(2) {
                    sh """
                        docker build \
                        --network=host \
                        -f node.Dockerfile \
                        -t ${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER} \
                        .
                    """
                }

                retry(2) {
                    sh """
                        docker build \
                        --network=host \
                        -f mysql.Dockerfile \
                        -t ${DOCKER_HUB_USER}/${DATABASE_IMAGE_NAME}:${BUILD_NUMBER} \
                        .
                    """
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
                    echo "=== Deploy Canary ==="

                    docker stack deploy \
                    -c docker-compose_canary.yaml \
                    ${CANARY_APP_NAME} \
                    --with-registry-auth

                    sleep 60

                    docker service ls \
                    --filter name=${CANARY_APP_NAME}
                '''
            }
        }

        stage('Canary Testing') {
            steps {
                sh '''
                    echo "=== Canary Testing ==="

                    SUCCESS=0
                    TESTS=5

                    for i in $(seq 1 $TESTS); do

                        echo "Canary test $i/$TESTS"

                        if curl -f -s \
                            --max-time 15 \
                            http://${MANAGER_IP}:8081/ \
                            > /tmp/canary_$i.html
                        then

                            if ! grep -iq \
                                "error\\|fatal\\|exception" \
                                /tmp/canary_$i.html
                            then
                                SUCCESS=$((SUCCESS + 1))
                                echo "OK"
                            else
                                echo "Error in page"
                            fi

                        else
                            echo "No response"
                        fi

                        sleep 3
                    done

                    echo "Successful tests: $SUCCESS/$TESTS"

                    [ "$SUCCESS" -ge 4 ] || exit 1
                '''
            }
        }

        stage('Deploy Production') {
            steps {
                sh '''
                    echo "=== Production deployment ==="

                    if docker service inspect \
                        ${APP_NAME}_web-server \
                        > /dev/null 2>&1
                    then

                        echo "Existing production found"

                        docker service update \
                        --image ${DOCKER_HUB_USER}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER} \
                        --update-parallelism 1 \
                        --update-delay 10s \
                        ${APP_NAME}_web-server

                    else

                        echo "First production deployment"

                        docker stack deploy \
                        --prune \
                        -c docker-compose.yaml \
                        ${APP_NAME} \
                        --with-registry-auth

                    fi

                    sleep 60

                    docker service ls \
                    --filter name=${APP_NAME}
                '''
            }
        }

        stage('Final Verification') {
            steps {
                sh '''
                    echo "=== Final Verification ==="

                    SUCCESS=0

                    for i in $(seq 1 5); do

                        if curl -f -s \
                            --max-time 15 \
                            http://${MANAGER_IP}:8080/ \
                            > /dev/null
                        then
                            SUCCESS=$((SUCCESS + 1))
                            echo "Test $i OK"
                        else
                            echo "Test $i FAILED"
                        fi

                        sleep 3
                    done

                    echo "Final tests: $SUCCESS/5"

                    [ "$SUCCESS" -ge 4 ] || exit 1

                    echo "Production works"
                '''
            }
        }

        stage('Remove Canary') {
            steps {
                sh '''
                    docker stack rm ${CANARY_APP_NAME} || true
                '''
            }
        }
    }

    post {

        success {
            echo 'SUCCESS: pipeline completed'
        }

        failure {
            echo 'FAILURE: pipeline stopped'
        }

        always {
            echo 'Pipeline finished'
        }
    }
}