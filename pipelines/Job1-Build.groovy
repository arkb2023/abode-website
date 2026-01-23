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
          
          // 1. Pull & inspect
          sh """
            docker pull ${image} || exit 1
            docker inspect ${image} > image-info.json
          """
          
          // 2. FIXED: Dynamic port + cleanup
          sh """
            # Find free port
            FREE_PORT=\$(python3 -c 'import socket; s=socket.socket(); s.bind((\"\", 0)); print(s.getsockname()[1]); s.close()')
            
            # Run container + test
            docker run -d --name smoke-test -p \$FREE_PORT:80 ${image}
            sleep 3
            
            # Health check
            curl -f http://localhost:\$FREE_PORT/ || exit 1
            curl -f http://localhost:\$FREE_PORT/ > smoke-test.html
            
            # Cleanup
            docker stop smoke-test
            docker rm smoke-test
          """
          
          // 3. Metadata
          sh "docker image ls ${image} --format '{{.Size}}' > image-size.txt"
          
          env.IS_MAIN = params.image_tag.startsWith('main-')
          currentBuild.description = "${image} | Port: \$FREE_PORT | Branch: ${env.IS_MAIN}"
        }
      }
    }
  }
  
  post {
    always {
      archiveArtifacts artifacts: 'image-info.json,image-size.txt,smoke-test.html', allowEmptyArchive: true
    }
    success { echo "Image validated successfully" }
    failure { echo "Validation failed" }
  }
}
