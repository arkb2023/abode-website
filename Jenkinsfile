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
                        chmod +x ./scripts/build.sh
                        ./scripts/build.sh "${DOCKER_HUB_USER}" "${IMAGE_NAME}" "${BUILD_TAG}" "${DOCKER_USER}" "${DOCKER_PASS}"
                    '''
                }
            }
        }
        stage('Test') {
            steps {
                sh '''
                    chmod +x ./scripts/test.sh
                    ./scripts/test.sh "${IMAGE}" 10 3
                '''
            }
        }
        stage('Deploy Prod') {
            when { expression { env.branch == 'refs/heads/main' } }
            steps {
                sshagent(credentials: ['prod-ssh-key']) {
                    sh '''
                        chmod +x ./scripts/deploy.sh
                        ./scripts/deploy.sh "${PROD_USER}" "${PROD_HOST}" "${IMAGE}"
                    '''
                }
            }
        }
    }
    post {
        always { cleanWs() }
        failure { echo "Pipeline FAILED - ${IMAGE}" }
        success { echo "Pipeline SUCCESS - ${IMAGE} deployed" }
    }
}
