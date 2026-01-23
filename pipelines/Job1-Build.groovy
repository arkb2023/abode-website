pipeline {
  agent any
  
  parameters {
    string(name: 'image_tag', defaultValue: 'latest', description: 'DockerHub tag')
    string(name: 'dh_repo', defaultValue: 'abode-website', description: 'DockerHub repo')
  }
  
  stages {
    stage('Image Validation') {
      steps {
        script {
          // Security scan (Trivy or Clair)
          sh """
            docker pull arkb2023/\${dh_repo}:\${image_tag} || exit 1
            
            # Vulnerability scan (install trivy if needed)
            curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
            trivy image --exit-code 1 --no-progress --severity HIGH,CRITICAL arkb2023/\${dh_repo}:\${image_tag}
            
            # Smoke test
            docker run --rm arkb2023/\${dh_repo}:\${image_tag} curl -f http://localhost || exit 1
          """
          
          // Branch detection for reporting
          env.IS_MAIN = params.image_tag.startsWith('main-') ? 'true' : 'false'
          currentBuild.description = "Image: \${dh_repo}:\${image_tag} | Branch: \${IS_MAIN}"
        }
      }
    }
  }
  
  post {
    always {
      archiveArtifacts artifacts: '**/*.json,**/trivy.html', allowEmptyArchive: true
      script {
        env.PIPELINE_STATUS = currentBuild.result ?: 'SUCCESS'
      }
    }
    success {
      echo "Image validated: ${dh_repo}:${image_tag}"
    }
    failure {
      echo "Image validation failed"
    }
  }
}
