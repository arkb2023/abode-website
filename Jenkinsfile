pipeline {
    agent any
    
    parameters {
        string(name: 'PROD_HOST', defaultValue: '10.158.148.115', description: 'Prod VM IP')
        string(name: 'PROD_USER', defaultValue: 'ubuntu', description: 'Prod SSH user')
    }
    
    stages {
        stage('Load Config') {
            steps {
                script {
                    def props = readProperties file: 'config.properties'
                    
                    env.DOCKER_HUB_USER = props.DOCKER_HUB_USER
                    env.IMAGE_NAME = props.IMAGE_NAME
                    env.PROD_HOST = params.PROD_HOST ?: props.PROD_HOST
                    env.PROD_USER = params.PROD_USER ?: props.PROD_USER
                    env.BUILD_TAG = "${props.BUILD_TAG_PREFIX}-${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
                    env.IMAGE = "${env.DOCKER_HUB_USER}/${env.IMAGE_NAME}:${env.BUILD_TAG}"
                    
                    // Determine which branch this is
                    def branch = env.branch ?: 'unknown'
                    env.IS_MAIN = (branch == 'refs/heads/main') ? 'true' : 'false'
                    env.IS_DEVELOP = (branch == 'refs/heads/develop') ? 'true' : 'false'
                    
                    echo "════════════════════════════════════"
                    echo "Build Configuration"
                    echo "════════════════════════════════════"
                    echo "Image: ${env.IMAGE}"
                    echo "Branch: ${branch}"
                    echo "Is Main: ${env.IS_MAIN}"
                    echo "Is Develop: ${env.IS_DEVELOP}"
                    if (env.IS_MAIN == 'true') {
                        echo "Pipeline Mode: BUILD → TEST → DEPLOY"
                    } else {
                        echo "Pipeline Mode: BUILD → TEST (no deploy)"
                    }
                    echo "════════════════════════════════════"
                }
            }
        }
        
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
            when {
                expression { env.IS_MAIN == 'true' }
            }
            steps {
                echo "Deploying to Production (main branch only)"
                sshagent(credentials: ['prod-ssh-key']) {
                    sh '''
                        chmod +x ./scripts/deploy.sh
                        ./scripts/deploy.sh "${PROD_USER}" "${PROD_HOST}" "${IMAGE}"
                    '''
                }
            }
        }
        
        stage('Summary') {
            steps {
                script {
                    if (env.IS_MAIN == 'true') {
                        echo "Full Pipeline Complete: Build → Test → Deploy (Prod)"
                        echo "Live at: http://${PROD_HOST}"
                    } else {
                        echo "Build & Test Complete"
                        echo "Ready for manual deploy (current branch: ${env.branch})"
                    }
                }
            }
        }
    }
    
    post {
        always { cleanWs() }
        failure { echo "Pipeline FAILED" }
        success { echo "Pipeline SUCCESS" }
    }
}
