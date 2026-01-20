// build
// test
// deploy
pipeline {
    agent any
    environment {
        DOCKER_HUB_USER = "arkb2023"
        IMAGE_NAME = "abode-website"
        //BUILD_TAG = "v1.0-${BUILD_NUMBER}-${GIT_COMMIT:0:7}"
        BUILD_TAG       = "v1.0-${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
    }
    parameters {
        string(name: 'PROD_HOST', defaultValue: '10.158.148.115', description: 'Prod VM IP')
        string(name: 'PROD_USER', defaultValue: 'ubuntu', description: 'Prod SSH user')
    }    
    stages {
        stage('Build') {
            steps {
              withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', 
                                                usernameVariable: 'DOCKER_USER', 
                                                passwordVariable: 'DOCKER_PASS')]) {
                sh '''
                docker build -t ${DOCKER_HUB_USER}/${IMAGE_NAME}:${BUILD_TAG} .
                echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                docker push ${DOCKER_HUB_USER}/${IMAGE_NAME}:${BUILD_TAG}
                echo "BUILD_TAG=${BUILD_TAG}" > build.properties
                '''
              }
            }
        }
        stage('Test') {
            steps {
              script {
                sh '''
                  . build.properties 2>/dev/null || BUILD_TAG="v1.0-${BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
                  IMAGE="${DOCKER_HUB_USER}/${IMAGE_NAME}:${BUILD_TAG}"
                  echo "Testing image: ${IMAGE}"
                  # sh 'bash tests/test.sh ${DOCKER_HUB_USER} ${IMAGE_NAME} ${BUILD_TAG}'
                  # Test 1: Files exist
                  docker run --rm ${IMAGE} sh -c "
                    ls -la /var/www/html/ &&
                    test -f /var/www/html/index.html &&
                    test -f /var/www/html/images/github3.jpg &&
                    echo 'Files OK!'
                  "
                  # Health check (Apache responds)
                  docker run -d -p 8080:80 --name test-web "${IMAGE}"
                  sleep 3
                  curl -f http://localhost:8080/ || exit 1
                  docker stop test-web || true
                  docker rm test-web || true
                  
                  echo "All tests PASSED!"
                '''
              }
            }
        }
        stage('Deploy Prod') {
            when { branch 'main' }
            steps {
                sshagent(credentials: ['prod-ssh-key']) {
                    sh '''
                    . build.properties
                    ssh -o StrictHostKeyChecking=no ${PROD_USER}@${PROD_HOST} << EOF
                    IMAGE="${DOCKER_HUB_USER}/${IMAGE_NAME}:${BUILD_TAG}"
                    echo "Deploying image: ${IMAGE}"
                    docker pull ${IMAGE}
                    docker stop webapp || true
                    docker rm webapp || true
                    docker run -d --name webapp -p 80:80 ${IMAGE}
                    docker ps | grep webapp
                    EOF
                    '''
                }
            }
        }
    }
    post {
        always {
            cleanWs()
        }
    }    
}
