pipeline {
  agent any
  
  parameters {
    string(name: 'image_tag', defaultValue: 'latest')
    string(name: 'dh_repo', defaultValue: 'abode-website')
  }
  
  stages {
    stage('Image Validation') {
      steps {
        script {
          def image = "arkb2023/${params.dh_repo}:${params.image_tag}"
          
          sh """
            chmod +x scripts/smoke.sh
            ./scripts/smoke.sh "${image}"
          """
          
          env.IS_MAIN = params.image_tag.startsWith('main-')
          currentBuild.description = "${image} | Branch: ${env.IS_MAIN}"
        }
      }
    }
  }
  
  post {
    always {
      archiveArtifacts artifacts: 'image-info.json,image-size.txt,smoke-test.html', allowEmptyArchive: true
    }
    success { echo "Smoke test passed" }
    failure { echo "Smoke test failed" }
  }
}
