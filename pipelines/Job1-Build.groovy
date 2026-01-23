pipeline {
  agent any
  
  parameters {
    string(name: 'image_tag', defaultValue: 'latest', description: 'DockerHub tag (e.g., main-v1.0.xx)')
    string(name: 'dh_repo', defaultValue: 'abode-website', description: 'DockerHub repo')
  }
  
  stages {
    stage('Image Validation') {
      steps {
        script {
          def image = "arkb2023/${params.dh_repo}:${params.image_tag}"
          
          // 1. Basic pull & existence check
          sh """
            docker pull ${image} || exit 1
            docker inspect ${image} > image-info.json
          """
          
          // 2. Lightweight smoke test (no install)
          sh """
            docker run --rm --network none ${image} curl -f http://localhost/ || exit 1
            docker image ls ${image} --format '{{.Size}}' > image-size.txt
          """
          
          // 3. Branch detection
          env.IS_MAIN = params.image_tag.startsWith('main-')
          currentBuild.description = "Image: ${image} | Branch: ${env.IS_MAIN} | Size: \$(cat image-size.txt)"
        }
      }
    }
  }
  
  post {
    always {
      archiveArtifacts artifacts: 'image-info.json,image-size.txt', allowEmptyArchive: true
    }
    success { 
      echo "Image validated successfully"
    }
    failure { 
      echo "Image validation failed" 
    }
  }
}
