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
              // script {
              //     env.BUILD_TAG = "v1.0-${BUILD_NUMBER}"
              // }
              withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', 
                                                usernameVariable: 'DOCKER_USER', 
                                                passwordVariable: 'DOCKER_PASS')]) {
                sh '''
                docker build -t ${DOCKER_HUB_USER}/${IMAGE_NAME}:${BUILD_TAG} .
                echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                docker push ${DOCKER_HUB_USER}/${IMAGE_NAME}:${BUILD_TAG}
                #echo "BUILD_TAG=${BUILD_TAG}" > build.properties
                '''
              }
            }
        }
        stage('Test') {
            steps {
              script {
                sh '''
                  IMAGE=${DOCKER_HUB_USER}/${IMAGE_NAME}:${BUILD_TAG}
                  echo "Testing: $IMAGE"
                  
                  # Verify files
                  docker run --rm $IMAGE ls -la /var/www/html/
                  docker run --rm $IMAGE test -f /var/www/html/index.html
                  docker run --rm $IMAGE test -f /var/www/html/images/github3.jpg
                  
                  # Spin up + healthcheck
                  docker rm -f test-web || true
                  docker run -d --name test-web -p 8081:80 $IMAGE
                  
                  # Retry curl until ready (max 30s)
                  for i in {1..10}; do
                    sleep 3
                    if curl -f -s http://localhost:8081/ > /dev/null; then
                      echo "Healthcheck PASSED on attempt $i"
                      break
                    fi
                    echo "Attempt $i/10 failed, retrying..."
                  done
                  
                  # Final verification
                  curl -s http://localhost:8081/
                  docker stop test-web && docker rm test-web
                  echo "Tests PASSED!"
                '''                
              }
            }
        }

      stage('Print Trigger Info') {
        steps {
          echo "Triggered by branch: ${env.branch}, SHA: ${env.sha}"
        }
      }        
      stage('Deploy Prod') {
        when {
          expression { env.branch == 'refs/heads/main' }
        }
        steps {
          echo "Deploying to prod!"
          sshagent(credentials: ['prod-ssh-key']) {
              sh '''    
              IMAGE="${DOCKER_HUB_USER}/${IMAGE_NAME}:${BUILD_TAG}"
              ssh -o StrictHostKeyChecking=no ${PROD_USER}@${PROD_HOST} << 'EOF'
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
