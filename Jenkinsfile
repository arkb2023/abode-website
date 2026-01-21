pipeline {
    agent any
    
    environment {
        DOCKER_HUB_USER = "arkb2023"
        IMAGE_NAME = "abode-website"
        BUILD_TAG = "v1.0-${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
        IMAGE = "${DOCKER_HUB_USER}/${IMAGE_NAME}:${BUILD_TAG}"
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
                        docker build -t ${IMAGE} .
                        echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                        docker push ${IMAGE}
                        docker logout
                    '''
                }
            }
        }
        
        stage('Test') {
            steps {
                sh '''
                    echo "Testing: ${IMAGE}"
                    
                    # Verify files in image
                    docker run --rm ${IMAGE} ls -la /var/www/html/
                    docker run --rm ${IMAGE} test -f /var/www/html/index.html
                    docker run --rm ${IMAGE} test -f /var/www/html/images/github3.jpg
                    
                    # Start test container
                    docker rm -f test-web || true
                    docker run -d --name test-web -p 8081:80 ${IMAGE}
                    
                    # Healthcheck: retry until ready (max 30s)
                    for i in {1..30}; do
                        sleep 3
                        if curl -f -s http://localhost:8081/ > /dev/null; then
                            echo "Healthcheck PASSED on attempt $i"
                            break
                        fi
                        echo "Attempt $i/10 - container not ready yet..."
                    done
                    
                    # Final smoke test
                    curl -s http://localhost:8081/ | head -20
                    docker stop test-web && docker rm test-web
                    echo "Tests PASSED!"
                '''
            }
        }
        
        stage('Deploy Prod') {
            when {
                expression { env.branch == 'refs/heads/main' }
            }
            steps {
                echo "Deploying ${IMAGE} to prod (${PROD_HOST})"
                sshagent(credentials: ['prod-ssh-key']) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ${PROD_USER}@${PROD_HOST} << EOF
                            IMAGE="${IMAGE}"
                            echo "Pulling: \$IMAGE"
                            docker pull \$IMAGE
                            
                            echo "Stopping old container..."
                            docker stop webapp || true
                            docker rm webapp || true
                            
                            echo "Starting new container..."
                            docker run -d --name webapp -p 80:80 \$IMAGE
                            
                            echo "Deployment complete:"
                            docker ps | grep webapp
EOF
                    '''
                }
            }
        }
    }
    
    post {
        always {
            echo "Cleaning workspace..."
            cleanWs()
        }
        failure {
            echo "Pipeline FAILED - Review logs above"
        }
        success {
            echo "Pipeline SUCCESS - ${IMAGE} deployed to prod"
        }
    }
}
