pipeline {
  agent any
  
  parameters {
    string(name: 'image_tag', defaultValue: 'latest')
    string(name: 'dh_repo', defaultValue: 'abode-website')
    string(name: 'TEST_USER', defaultValue: 'ubuntu')
    string(name: 'TEST_HOST', defaultValue: '10.158.148.84')
    string(name: 'TEST_PORT', defaultValue: '8081')
  }
  
  stages {
    stage('Test Deployment') {
      steps {
        sshagent(credentials: ['prod-ssh-key']) {
          sh """
            chmod +x scripts/test.sh
            ./scripts/test.sh "\${TEST_USER}" "\${TEST_HOST}" \
              "arkb2023/\${dh_repo}:\${image_tag}" "\${TEST_PORT}"
          """
        }
      }
    }
  }
  
  post {
    success { echo "Tests passed on ${TEST_HOST}:${TEST_PORT}" }
    failure { echo "Tests failed" }
  }
}
