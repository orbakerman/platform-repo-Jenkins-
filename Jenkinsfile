pipeline {
  agent {
    docker {
      image 'python:3.12-slim'
      args '-v /var/run/docker.sock:/var/run/docker.sock'
    }
  }

  options {
    timestamps()
    ansiColor('xterm')
  }

  environment {
    AWS_REGION   = 'us-east-1'
    ECR_REPO     = 'orbak-app1'
  }

  stages {
    stage('Prepare tools') {
      steps {
        sh '''
          python -m pip install --upgrade pip
          pip install --no-cache-dir awscli==1.* pytest
          docker --version
          aws --version
        '''
      }
    }

    stage('Compute ECR registry') {
      steps {
        script {
          def acct = sh(returnStdout: true, script: "aws sts get-caller-identity --query Account --output text").trim()
          env.ECR_REGISTRY = "${acct}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
          env.IMAGE_URI = "${env.ECR_REGISTRY}/${env.ECR_REPO}"
        }
      }
    }

    stage('Login to ECR') {
      steps {
        sh '''
          aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" || \
          aws ecr create-repository --repository-name "$ECR_REPO" --region "$AWS_REGION"
          aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"
        '''
      }
    }

    stage('Build Image') {
      steps {
        sh '''
          COMMIT_SHORT=$(git rev-parse --short=8 HEAD)
          docker build -t local:${COMMIT_SHORT} .
          echo "COMMIT_SHORT=${COMMIT_SHORT}" > .build_env
        '''
      }
    }

    stage('Test') {
      steps {
        sh '''
          mkdir -p test-results
          pytest -q --junitxml=test-results/junit.xml || exit 1
        '''
      }
      post {
        always {
          junit 'test-results/junit.xml'
          archiveArtifacts artifacts: 'test-results/junit.xml', onlyIfSuccessful: false
        }
      }
    }

    stage('Tag & Push (PR builds)') {
      when { expression { return env.CHANGE_ID != null } }
      steps {
        sh '''
          source .build_env
          TAG="pr-${CHANGE_ID}-${BUILD_NUMBER}"
          docker tag local:${COMMIT_SHORT} ${IMAGE_URI}:${TAG}
          docker push ${IMAGE_URI}:${TAG}
        '''
      }
    }

    stage('Tag & Push (main)') {
      when { branch 'main' }
      steps {
        sh '''
          source .build_env
          RELEASE_TAG="build-${BUILD_NUMBER}"
          docker tag local:${COMMIT_SHORT} ${IMAGE_URI}:${RELEASE_TAG}
          docker tag local:${COMMIT_SHORT} ${IMAGE_URI}:latest
          docker push ${IMAGE_URI}:${RELEASE_TAG}
          docker push ${IMAGE_URI}:latest
        '''
      }
    }

    stage('Deploy to Production EC2') {
      when { branch 'main' }
      environment {
        PROD_HOST = 'ec2-user@3.85.84.65'
      }
      steps {
        sshagent (credentials: ['prod-ec2-ssh-key']) {
          sh '''
            ssh -o StrictHostKeyChecking=no "$PROD_HOST" bash -s <<'EOS'
set -euo pipefail
AWS_REGION='"$AWS_REGION"'
ECR_REGISTRY='"$ECR_REGISTRY"'
ECR_REPO='"$ECR_REPO"'
IMAGE_URI="${ECR_REGISTRY}/${ECR_REPO}"
RELEASE_TAG="build-'"$BUILD_NUMBER"'"

aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"
docker pull "${IMAGE_URI}:${RELEASE_TAG}"
docker rm -f app || true
docker run -d --name app -p 80:8000 --restart=always "${IMAGE_URI}:${RELEASE_TAG}"
EOS
          '''
        }
      }
    }

    stage('Health Verification') {
      when { branch 'main' }
      environment {
        PROD_URL = 'http://3.85.84.65/health'
      }
      steps {
        sh '''
          echo "Probing $PROD_URL ..."
          for i in $(seq 1 10); do
            if curl -fsS "$PROD_URL" > /dev/null; then
              echo "Health OK"; exit 0
            fi
            echo "Not healthy yet... retry $i/10"
            sleep 3
          done
          echo "Health check failed"; exit 1
        '''
      }
    }
  }

  post {
    failure {
      echo " Pipeline failed"
    }
    success {
      echo " Pipeline succeeded"
    }
  }
}

