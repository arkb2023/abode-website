// build
// test
// deploy
pipeline {
    agent any
    environment {
        DOCKER_HUB_USER = "arkb2023"
        IMAGE_NAME = "abode-website"
        //BUILD_TAG = "v1.0-${BUILD_NUMBER}-${GIT_COMMIT:0:7}"
        //BUILD_TAG       = "v1.0-${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
    }
    parameters {
        string(name: 'PROD_HOST', defaultValue: '10.158.148.115', description: 'Prod VM IP')
        string(name: 'PROD_USER', defaultValue: 'ubuntu', description: 'Prod SSH user')
    }    
    stages {
        stage('Build') {
            steps {
              script {
                  env.BUILD_TAG = "v1.0-${BUILD_NUMBER}"
              }
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
                IMAGE="${DOCKER_HUB_USER}/${IMAGE_NAME}:${BUILD_TAG}"
                echo "Testing: $IMAGE"
                
                # Test files
                docker run --rm "$IMAGE" ls -la /var/www/html/
                docker run --rm "$IMAGE" test -f /var/www/html/index.html
                docker run --rm "$IMAGE" test -f /var/www/html/images/github3.jpg
                
                # Health check (use 8081 - Jenkins=8080)
                docker rm -f test-web 2>/dev/null || true
                docker run -d --name test-web -p 8081:80 "$IMAGE"
                sleep 5
                curl -f http://localhost:8081/
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
              ssh -o StrictHostKeyChecking=no ${PROD_USER}@${PROD_HOST} << 'EOF'
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
