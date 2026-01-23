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
          def image = "arkb2023/${params.dh_repo}:${params.image_tag}"
          
          // 1. Pull & inspect
          sh """
            docker pull ${image} || exit 1
            docker inspect ${image} > image-info.json
          """
          
          // 2. FIXED: Port mapping for web server smoke test
          sh """
            docker run --rm -p 8080:80 ${image} &
            APP_PID=\$!
            sleep 3
            curl -f http://localhost:8080/ || exit 1
            kill \$APP_PID || true
          """
          
          // 3. Size + layers
          sh "docker image ls ${image} --format '{{.Size}}' > image-size.txt"
          
          env.IS_MAIN = params.image_tag.startsWith('main-')
          currentBuild.description = "✅ ${image} | Branch: ${env.IS_MAIN}"
        }
      }
    }
  }
  
  post {
    always {
      archiveArtifacts artifacts: 'image-info.json,image-size.txt', allowEmptyArchive: true
    }
    success { echo "Image validated: ${dh_repo}:${image_tag}" }
    failure { echo "Validation failed" }
  }
}
