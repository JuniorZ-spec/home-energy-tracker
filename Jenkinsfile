pipeline {
  agent any

  environment {
    // Docker Hub namespace (username or org) images are pushed under, e.g. home-energy-tracker/user-service
    DOCKERHUB_NAMESPACE = 'CHANGE_ME'
    // Public IP of the Azure VM — from `terraform output instance_public_ip` in Terraform/
    AZURE_VM_HOST = 'CHANGE_ME'
    IMAGE_TAG = "${env.BUILD_NUMBER}"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build & Test') {
      steps {
        script {
          def services = [
            'user-service',
            'device-service',
            'ingestion-service',
            'usage-service',
            'alert-service',
            'insight-service',
            'api-gateway'
          ]

          for (svc in services) {
            dir(svc) {
              echo "Building ${svc}..."
              retry(3) {
                sh '''
                  if [ -x ./mvnw ] && [ -f ./.mvn/wrapper/maven-wrapper.properties ]; then
                    chmod +x mvnw
                    ./mvnw -B -q -DskipTests package
                  else
                    mvn -B -q -DskipTests package
                  fi
                '''
              }
            }
          }
        }
      }
    }

    stage('Build & Push Docker Images') {
      steps {
        script {
          def services = [
            'user-service',
            'device-service',
            'ingestion-service',
            'usage-service',
            'alert-service',
            'insight-service',
            'api-gateway'
          ]

          withCredentials([usernamePassword(
            credentialsId: 'dockerhub-credentials',
            usernameVariable: 'DOCKERHUB_USERNAME',
            passwordVariable: 'DOCKERHUB_PASSWORD'
          )]) {
            sh """
              echo "${DOCKERHUB_PASSWORD}" | docker login --username ${DOCKERHUB_USERNAME} --password-stdin
            """

            for (svc in services) {
              def repo = "${DOCKERHUB_NAMESPACE}/home-energy-tracker-${svc}"
              retry(3) {
                sh """
                  docker build -t ${repo}:${IMAGE_TAG} -t ${repo}:latest ${svc}
                """
              }
              retry(3) {
                sh """
                  docker push ${repo}:${IMAGE_TAG}
                  docker push ${repo}:latest
                """
              }
            }
          }
        }
      }
    }

    stage('Deploy to Azure VM') {
      steps {
        withCredentials([sshUserPrivateKey(
          credentialsId: 'azure-vm-ssh-key',
          keyFileVariable: 'SSH_KEY',
          usernameVariable: 'SSH_USER'
        )]) {
          sh """
            ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i ${SSH_KEY} ${SSH_USER}@${AZURE_VM_HOST} 'echo SSH_OK'
            scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i ${SSH_KEY} docker-compose.prod.yml ${SSH_USER}@${AZURE_VM_HOST}:~/docker-compose.prod.yml
          """

          withCredentials([usernamePassword(
            credentialsId: 'dockerhub-credentials',
            usernameVariable: 'DOCKERHUB_USERNAME',
            passwordVariable: 'DOCKERHUB_PASSWORD'
          )]) {
            sh """
              ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i ${SSH_KEY} ${SSH_USER}@${AZURE_VM_HOST} '
                echo "${DOCKERHUB_PASSWORD}" | docker login --username ${DOCKERHUB_USERNAME} --password-stdin
              '
            """
          }

          sh """
            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${AZURE_VM_HOST} '
              export IMAGE_TAG=${IMAGE_TAG}
              export DOCKERHUB_NAMESPACE=${DOCKERHUB_NAMESPACE}
              docker compose -f docker-compose.prod.yml pull
              docker compose -f docker-compose.prod.yml up -d
            '
          """
        }
      }
    }
  }

  post {
    success {
      echo "Pipeline succeeded — build ${IMAGE_TAG} deployed to ${AZURE_VM_HOST}"
    }
    failure {
      echo "Pipeline failed — check the stage logs above"
    }
    always {
      echo 'Pipeline finished'
      echo 'Deployment step completed'
    }
  }
}
