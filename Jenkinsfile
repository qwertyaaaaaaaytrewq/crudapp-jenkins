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
                    docker stack deploy \
                        -c docker-compose_canary.yaml \
                        ${CANARY_APP_NAME} \
                        --with-registry-auth

                    sleep 40

                    docker service ls
                '''
            }
        }

        stage('Canary Testing') {
            steps {
                sh '''
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

        stage('Deploy Production') {
            steps {
                sh '''
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
        always {
            echo 'Pipeline finished.'
        }

        success {
            echo 'SUCCESS: Pipeline completed.'
        }

        failure {
            echo 'FAILURE: Pipeline stopped.'
        }
    }
}