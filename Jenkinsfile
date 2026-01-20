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
    stages {
        stage('Build') {
            steps {
                sh '''
                docker build -t ${DOCKER_HUB_USER}/${IMAGE_NAME}:${BUILD_TAG} .
                echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                docker push ${DOCKER_HUB_USER}/${IMAGE_NAME}:${BUILD_TAG}
                echo "BUILD_TAG=${BUILD_TAG}" > build.properties
                '''
            }
        }
        stage('Test') {
            steps {
                sh 'bash tests/test.sh'
            }
        }
        stage('Deploy Prod') {
            when { branch 'main' }
            steps {
                sshagent(credentials: ['prod-ssh-key']) {
                    sh '''
                    source build.properties
                    ssh ubuntu@<PROD_EC2_IP> << EOF
                    docker pull ${DOCKER_HUB_USER}/${IMAGE_NAME}:${BUILD_TAG}
                    docker stop webapp || true
                    docker rm webapp || true
                    docker run -d --name webapp -p 80:80 ${DOCKER_HUB_USER}/${IMAGE_NAME}:${BUILD_TAG}
                    EOF
                    '''
                }
            }
        }
    }
}
