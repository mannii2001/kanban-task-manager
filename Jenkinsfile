pipeline {

    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {

        AWS_REGION = 'ap-south-1'
        AWS_ACCOUNT_ID = '600402507299'

        ECR_REGISTRY =
            '600402507299.dkr.ecr.ap-south-1.amazonaws.com'

        ECR_REPOSITORY = 'kanban-task-manager'

        GITHUB_REPO = 'https://github.com/mannii2001/kanban-task-manager.git/'

        CONTAINER_NAME = 'kanban-app'

        APP_PORT = '80'

        DEPLOY_ATTEMPTED = 'false'
    }
    
       stages {

        // STAGE 1: CHECKOUT SOURCE

        stage('Checkout Source') {

            steps {

                git branch: 'main',
                    url: "https://github.com/mannii2001/kanban-task-manager.git/"

                script {

                    env.GIT_SHA = sh(
                        script: 'git rev-parse HEAD',
                        returnStdout: true
                    ).trim()

                    env.IMAGE_URI =
                        "${ECR_REGISTRY}/${ECR_REPOSITORY}:${GIT_SHA}"

                    echo "Git SHA: ${GIT_SHA}"

                    echo "Docker Image: ${IMAGE_URI}"
                }
            }
        }
    
    // STAGE 2: DOCKER BUILD

        stage('Docker Build') {

            steps {

                sh '''
                    set -e

                    docker build \
                      -t ${ECR_REPOSITORY}:${GIT_SHA} .

                    docker tag \
                      ${ECR_REPOSITORY}:${GIT_SHA} \
                      ${IMAGE_URI}
                    
                '''
            }
        }
        
        stage('Push to ECR') {

            steps {

                sh '''
                    set -e

                    aws ecr get-login-password \
                      --region ${AWS_REGION} |
                    docker login \
                      --username AWS \
                      --password-stdin ${ECR_REGISTRY}

                    docker push ${IMAGE_URI}
                '''
            }
        }
        stage('Deploy to EC2') {
            steps {
                script {
                    env.DEPLOY_ATTEMPTED = 'true'

                    sh '''
                        set -e

                        echo "Saving previous image..."

                        OLD_IMAGE=$(docker inspect \
                          --format='{{.Config.Image}}' \
                          ${CONTAINER_NAME} 2>/dev/null || true)

                        printf '%s\\n' "$OLD_IMAGE" > old-image.txt

                        echo "Pulling new image..."

                        docker pull ${IMAGE_URI}

                        echo "Removing old container..."

                        docker rm -f ${CONTAINER_NAME} \
                          2>/dev/null || true

                        echo "Starting new container..."

                        docker run -d \
                          --name ${CONTAINER_NAME} \
                          --restart unless-stopped \
                          --cpus="1.0" \
                          --memory="128m" \
                          -p ${APP_PORT}:8080 \
                          ${IMAGE_URI}

                        echo "Checking container status..."

                        docker ps --filter name=${CONTAINER_NAME}
                    '''
                }
            }
        }
        stage('Health Check') {

            steps {

                sh '''
                    set -e

                    echo "Checking application health..."

                    HEALTHY=false

                    for i in $(seq 1 15); do

                        if curl -fsS \
                          http://localhost:${APP_PORT}/health \
                          >/dev/null; then

                            HEALTHY=true

                            echo "Application is healthy!"

                            break
                        fi

                        echo "Waiting for application..."

                        sleep 5

                    done

                    if [ "$HEALTHY" != "true" ]; then

                        echo "Health check failed!"

                        exit 1
                    fi
                '''
            }
        }
    }
    post {

        success {
            echo '''
            =====================================
               PIPELINE EXECUTION SUCCESSFUL
            =====================================
            '''
            echo "Application deployed successfully."
            echo "Image: ${IMAGE_URI}"
        }

        failure {
            echo '''
            =====================================
               PIPELINE EXECUTION FAILED
            =====================================
            '''
            script {

                if (env.DEPLOY_ATTEMPTED == 'true') {

                    echo "Starting rollback..."

                    sh '''
                        set -e

                        OLD_IMAGE=$(cat old-image.txt 2>/dev/null || true)

                        docker rm -f ${CONTAINER_NAME} \
                          2>/dev/null || true

                        if [ -n "$OLD_IMAGE" ]; then

                            echo "Restoring previous image: $OLD_IMAGE"

                            docker run -d \
                              --name ${CONTAINER_NAME} \
                              --restart unless-stopped \
                              --cpus="1.0" \
                              --memory="128m" \
                              -p ${APP_PORT}:8080 \
                              "$OLD_IMAGE"

                            echo "Verifying rollback health..."

                            ROLLBACK_HEALTHY=false

                            for i in $(seq 1 15); do

                                if curl -fsS \
                                  http://localhost:${APP_PORT}/health \
                                  >/dev/null; then

                                    ROLLBACK_HEALTHY=true

                                    break
                                fi

                                sleep 5
                            done

                            if [ "$ROLLBACK_HEALTHY" != "true" ]; then
                                echo "Rollback health check failed!"
                                exit 1
                            fi

                            echo "Rollback successful!"

                        else

                            echo "No previous image available!"
                            echo "Manual recovery required."

                        fi
                    '''
                }
            }
            echo "Check the stage logs for the error."
            echo "Previous application version is retained."
        }

        always {
            echo "Starting Jenkins and Docker cleanup..."

            // Clean Jenkins workspace

            deleteDir()

            // Clean Docker build cache and dangling images

            sh '''
                docker builder prune -f || true

                docker image prune -f || true
            '''

            echo "Workspace and Docker cleanup completed."
            echo "Pipeline execution finished."
        }
    }
}