pipeline {
  agent any
  
  parameters {
    string(name: 'image_tag', defaultValue: 'latest')
    string(name: 'dh_repo', defaultValue: 'abode-website')
    string(name: 'PROD_USER', defaultValue: 'ubuntu')
    string(name: 'PROD_HOST', defaultValue: '10.158.148.115')
    string(name: 'PROD_PORT', defaultValue: '80')
  }
  
  stages {
    stage('Production Deploy') {
      steps {
        sshagent(credentials: ['prod-ssh-key']) {
          sh """
            chmod +x scripts/deploy.sh
            ./scripts/deploy.sh "\${PROD_USER}" "\${PROD_HOST}" \
              "arkb2023/\${dh_repo}:\${image_tag}" "\${PROD_PORT}"
          """
        }
      }
    }
  }
  
  post {
    success { 
      echo "Deployed to http://${PROD_HOST}:${PROD_PORT}"
      publishHTML([
        allowMissing: false,
        alwaysLinkToLastBuild: true, 
        keepAll: true,
        reportDir: '.',
        reportFiles: 'deploy-success.html',
        reportName: 'Deployment Status'
      ])
    }
  }
}
