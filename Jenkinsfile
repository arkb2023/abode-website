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
                    try {
                        // Read config.properties from repo root
                        def configFile = readFile(file: 'config.properties')
                        def props = [:]
                        
                        // Parse properties manually
                        configFile.split('\n').each { line ->
                            if (line && !line.startsWith('#') && line.contains('=')) {
                                def (key, value) = line.split('=', 2)
                                props[key.trim()] = value.trim()
                            }
                        }
                        
                        // Set environment variables from config
                        env.DOCKER_HUB_USER = props.DOCKER_HUB_USER ?: 'arkb2023'
                        env.IMAGE_NAME = props.IMAGE_NAME ?: 'abode-website'
                        env.BUILD_TAG_PREFIX = props.BUILD_TAG_PREFIX ?: 'v1.0'
                        env.PROD_HOST = params.PROD_HOST ?: props.PROD_HOST ?: '10.158.148.115'
                        env.PROD_USER = params.PROD_USER ?: props.PROD_USER ?: 'ubuntu'
                        env.TEST_PORT = props.TEST_PORT ?: '8081'
                        
                        // Calculate BUILD_TAG
                        env.BUILD_TAG = "${env.BUILD_TAG_PREFIX}-${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
                        env.IMAGE = "${env.DOCKER_HUB_USER}/${env.IMAGE_NAME}:${env.BUILD_TAG}"
                        
                        // Determine branch info
                        def branch = env.branch ?: 'unknown'
                        env.IS_MAIN = (branch == 'refs/heads/main') ? 'true' : 'false'
                        env.IS_DEVELOP = (branch == 'refs/heads/develop') ? 'true' : 'false'
                        env.SHORT_BRANCH = branch.replaceAll('refs/heads/', '')
                        
                        // Log configuration
                        echo "════════════════════════════════════════════════"
                        echo "Configuration Loaded"
                        echo "════════════════════════════════════════════════"
                        echo "Image: ${env.IMAGE}"
                        echo "Branch: ${env.SHORT_BRANCH}"
                        echo "Build Mode: ${env.IS_MAIN == 'true' ? 'FULL (Build→Test→Deploy)' : 'TEST ONLY (Build→Test)'}"
                        echo "Prod Target: ${env.PROD_USER}@${env.PROD_HOST}"
                        echo "════════════════════════════════════════════════"
                        
                    } catch (Exception e) {
                        echo "Error loading config: ${e.message}"
                        echo "Proceeding with defaults..."
                        
                        env.DOCKER_HUB_USER = 'arkb2023'
                        env.IMAGE_NAME = 'abode-website'
                        env.BUILD_TAG_PREFIX = 'v1.0'
                        env.PROD_HOST = params.PROD_HOST ?: '10.158.148.115'
                        env.PROD_USER = params.PROD_USER ?: 'ubuntu'
                        env.BUILD_TAG = "${env.BUILD_TAG_PREFIX}-${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
                        env.IMAGE = "${env.DOCKER_HUB_USER}/${env.IMAGE_NAME}:${env.BUILD_TAG}"
                        env.SHORT_BRANCH = env.GIT_BRANCH ?: 'unknown'
                        env.IS_MAIN = (env.SHORT_BRANCH == 'main') ? 'true' : 'false'
                        env.TEST_PORT = env.TEST_PORT ?: '8081'
                    }
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
                    ./scripts/test.sh "${IMAGE}" 10 3 "${TEST_PORT}
                '''
            }
        }
        
        stage('Deploy Prod') {
            when {
                expression { env.IS_MAIN == 'true' }
            }
            steps {
                echo "Deploying to Production (${env.SHORT_BRANCH} branch)"
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
                    echo ""
                    echo "════════════════════════════════════════════════"
                    if (env.IS_MAIN == 'true') {
                        echo "Full Pipeline Complete"
                        echo "   Stages: Build → Test → Deploy"
                        echo "   Status: Live at http://${env.PROD_HOST}"
                    } else {
                        echo "Build & Test Complete"
                        echo "   Stages: Build → Test"
                        echo "   Status: Deploy skipped (${env.SHORT_BRANCH} branch)"
                    }
                    echo "════════════════════════════════════════════════"
                }
            }
        }
    }
    
    post {
        always { 
            cleanWs() 
        }
        failure { 
            echo "Pipeline FAILED"
        }
        success { 
            echo "Pipeline SUCCESS - Image: ${env.IMAGE}"
        }
    }
}
